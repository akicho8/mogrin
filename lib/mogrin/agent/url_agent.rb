# -*- coding: utf-8 -*-

if $0 == __FILE__
  require "../../mogrin"
end

require "httparty"

module Mogrin
  module Agent
    class UrlAgent < Base
      def initialize(base, url_info)
        super(base)
        @url_info = url_info
      end

      def result
        begin
          Timeout.timeout(@base.config[:timeout]) do
            @response_time = Benchmark.realtime do
              @response = HTTParty.get(c_url, site_options)
              @base.logger_puts("headers: #{@response.headers}")
            end
          end
        rescue => @error
          @base.logger_puts("ERROR: #{@error}")
        end
        super
      end

      private

      def c_x_runtime
        if @response
          @response.headers["x-runtime"]
        end
      end

      def site_options
        {:follow_redirects => false}.merge(@url_info[:options] || {})
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
        @response.code
      end

      def c_site_title
        if @response
          if md = @response.body.to_s.match(%r!<title>(?<site_title>.*?)</title>!im)
            md[:site_title]
          end
        end
      end

      module RevisionMethods
        private

        def c_revision
          # return "cc2a41342eb55087b06567184f4879cbed00f1f5"
          unless @revision
            if @response
              r = HTTParty.get(revision_url, site_options)
              if r.code == 200 && md = r.body.to_s.strip.match(/\A(?<revision>[a-z\d]+)/)
                @revision = md[:revision]
              end
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
            @base.command_run("git show -s --format=%cn #{c_revision}")
          end
        end

        def c_pending_count
          if c_revision
            @base.command_run("git log --oneline #{c_revision}..").force_encoding("UTF-8").lines.count
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
              str = @base.command_run("git show -s --format=%ci #{c_revision}")
              if str.present?
                @updated_at = Time.parse(str)
              end
            end
          end
          @updated_at
        end

        def c_before_days
          if c_revision
            str = @base.command_run("git show -s --format=%cr #{c_revision}")
            str = str.gsub(/\b(ago)\b/, "")      # "2 hours ago" => "2 hours"
            str = str.gsub(/([a-z])\w+/, '\1')   # "2 hours"     => "2 h"
            str = str.gsub(/\s+/, "")            # "2 h"         => "2h"
          end
          # if updated_at
          #   minutes = (Time.current.to_i - updated_at.to_i) / 60.0
          #   if minutes < 60
          #     "%dm" % minutes
          #   elsif minutes < 60 * 24
          #     "%.1fh" % (minutes / 60)
          #   else
          #     "%.1fd" % (minutes / 60 / 24)
          #   end
          # end
        end
      end

      include RevisionMethods
    end
  end
end

if $0 == __FILE__
  base = Mogrin::Core.new
  obj = Mogrin::Agent::UrlAgent.new(base, :url => ARGV.first)
  obj.instance_eval do
    p result
  end
end
