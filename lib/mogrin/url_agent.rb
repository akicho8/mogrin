# -*- coding: utf-8 -*-
module Mogrin
  class UrlAgent < Agent
    def initialize(base, url_info)
      super(base)
      @url_info = url_info
      @meta = {}
    end

    def result
      begin
        Timeout.timeout(@base.config[:timeout]) do
          @response_time = Benchmark.realtime do
            open(c_url, site_options){|f|
              @meta = f.meta
              @content = f.read
            }
          end
        end
      rescue => @error
        @base.logger_puts("ERROR: #{@error}")
      end
      super
    end

    private

    def c_x_runtime
      meta("x-runtime")
    end

    def site_options
      @url_info[:options] || {}
    end

    def c_response_time
      if @response_time
        "%.2f" % @response_time
      end
    end

    def c_desc
      @url_info[:desc]
    end

    def c_url
      URI(@url_info[:url]).normalize.to_s
    end

    def url_with_basic_auth
      if @url_info[:options] && @url_info[:options][:http_basic_authentication]
        c_url.gsub(%r{\A(\w+://)}){|str|str + "%s:%s@" % @url_info[:options][:http_basic_authentication]}
      else
        c_url
      end
    end

    def c_status
      if @error
        # if @error.message.match(/^redirection/)
        #   "リダイレクト"
        # else
        @error.message
      else
        @meta["status"]
      end
    end

    def session_key
      if @meta["set-cookie"]
        @meta["set-cookie"].slice(/\A\w+/)
      end
    end

    def c_server
      @meta["server"]
    end

    def meta(key)
      @meta[key.to_s]
    end

    def c_site_title
      if md = @content.to_s.match(%r!<title>(?<site_title>.*?)</title>!im)
        md[:site_title]
      end
    end

    module RevisionMethods
      private

      def c_revision
        # return "cc2a41342eb55087b06567184f4879cbed00f1f5"
        unless @revision
          str = nil
          begin
            str = Timeout.timeout(@base.config[:timeout]) do
              open(revision_url, site_options){|f|
                f.read
              }
            end
          rescue => error
            @base.logger_puts("ERROR: #{error}")
          end
          if str && md = str.strip.match(/\A(?<revision>[a-z\d]+)/)
            @revision = md[:revision]
          end
        end
        @revision
      end

      def site_top
        ui = URI.parse(c_url)
        "#{ui.scheme}://#{ui.host}"
      end

      def revision_url
        "#{site_top}/revision"
      end

      def c_commiter
        if c_revision
          @base.command_run("git log --pretty='%cn' #{c_revision}^..#{c_revision}")
        end
      end

      def c_pending_count
        if c_revision
          @base.command_run("git log --oneline #{c_revision}..").lines.count
        end
      end

      def c_updated_at_s
        if updated_at
          updated_at.strftime("%m-%d %H:%M")
        end
      end

      def updated_at
        unless @updated_at
          if c_revision
            str = @base.command_run("git log --pretty='%cd' #{c_revision}^..#{c_revision}")
            if str.present?
              @updated_at = Time.parse(str)
            end
          end
        end
        @updated_at
      end

      def c_before_days
        if updated_at
          minutes = (Time.current.to_i - updated_at.to_i) / 60.0
          if minutes < 60
            "%dm" % minutes
          elsif minutes < 60 * 24
            "%.1fh" % (minutes / 60)
          else
            "%.1fd" % (minutes / 60 / 24)
          end
        end
      end
    end

    include RevisionMethods
  end
end
