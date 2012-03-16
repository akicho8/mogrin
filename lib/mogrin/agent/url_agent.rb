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

      def run
        return if @base.config[:dry_run]
        begin
          @response_time = Benchmark.realtime do
            # FIXME: timeoutが効かない。存在しないドメインを叩くと30秒はフリーズする
            @response = HTTParty.get(a_url, site_options)
          end
        rescue => @error
          @base.logger_puts("ERROR: #{@error}")
        else
          @base.logger_puts("headers: #{@response.headers.inspect}")
        end
      end

      private

      def s_x_runtime
        if @response
          @response.headers["x-runtime"]
        end
      end

      def site_options
        {
          :follow_redirects => false,
          :timeout => @base.config[:timeout],
        }.merge(@url_info[:options] || {})
      end

      def s_response_time
        if @response_time
          "%.2f" % @response_time
        end
      end

      def a_desc
        @url_info[:desc]
      end

      def a_url
        URI(@url_info[:url]).normalize.to_s
      end

      def url_with_basic_auth
        if @url_info[:options] && @url_info[:options][:http_basic_authentication]
          a_url.gsub(%r{\A(\w+://)}){|str|str + "%s:%s@" % @url_info[:options][:http_basic_authentication]}
        else
          a_url
        end
      end

      def s_status
        if @response
          @response.code
        end
      end

      def s_site_title
        if @response
          if md = @response.body.to_s.match(%r!<title>(?<site_title>.*?)</title>!im)
            md[:site_title]
          end
        end
      end

      module RevisionMethods
        private

        def s_revision
          unless @revision
            if @response
              r = HTTParty.get(revision_url, site_options)
              if r.code == 200 && md = r.body.to_s.strip.match(/\A(?<revision>[a-z\d]{40})/i)
                @revision = md[:revision]
              end
            end
          end
          @revision
        end

        def site_top
          ui = URI.parse(a_url)
          "#{ui.scheme}://#{ui.host}"
        end

        def revision_url
          "#{site_top}/revision"
        end

        def t_commiter
          if s_revision
            @base.command_run("git show -s --format=%cn #{s_revision}")
          end
        end

        def t_pending_count
          if s_revision
            if str = @base.command_run("git log --oneline #{s_revision}..")
              str.force_encoding("UTF-8").lines.count
            end
          end
        end

        def s_updated_at_s
          if updated_at
            updated_at.strftime("%m-%d %H:%M")
          end
        end

        def updated_at
          unless @updated_at
            if s_revision
              if str = @base.command_run("git show -s --format=%ci #{s_revision}")
                @updated_at = Time.parse(str)
              end
            end
          end
          @updated_at
        end

        def t_before_days
          if s_revision
            if str = @base.command_run("git show -s --format=%cr #{s_revision}")
              str = str.gsub(/\b(ago)\b/, "")      # "2 hours ago" => "2 hours"
              str = str.gsub(/([a-z])\w+/, '\1')   # "2 hours"     => "2 h"
              str = str.gsub(/\s+/, "")            # "2 h"         => "2h"
            end
          end
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
