# -*- coding: utf-8 -*-
if $0 == __FILE__
  require "../../mogrin"
end

module Mogrin
  module Agent
    class HostAgent < Base
      def initialize(base, host_info)
        super(base)
        @host_info = host_info
      end

      private

      def a_desc
        @host_info[:desc]
      end

      def a_host
        @host_info[:host]
      end

      def t_name2ip
        @t_name2ip ||= Resolv.getaddress(a_host)
      end

      def t_ip2name
        if t_name2ip
          Resolv.getname(t_name2ip)
        end
      end

      def t_inside_hostname
        remote_run("hostname")
      end

      # ["16:41", "up", "4", "days,", "14:40,", "4", "users,", "load", "averages:", "0.89", "0.62", "0.58"]
      #                                                                                     ^^^^^^
      def t_loadavg
        if s = z_uptime
          s.split(/[,\s]+/)[-2]
        end
      end

      # 15:02  up 5 days, 22:47, 4 users, load averages: 0.31 0.44 0.48
      #        ^^^^^^^^^
      def t_uptime
        if s = z_uptime
          if md = s.match(/\bup\b(?<time>.*?),/)
            md[:time].gsub(/days?/, "d").gsub(/hours?/, "h").gsub(/\s/, "")
          end
        end
      end

      def t_pid_count
        if v = process_count('')
          v - 1
        end
      end

      def t_passenger_count
        process_count('passenger')
      end

      def t_nginx_count
        process_count('nginx: master')
      end

      def t_nginx_count2
        process_count('nginx: worker')
      end

      def t_unicorn_count
        process_count('unicorn_rails master')
      end

      def t_unicorn_count2
        process_count('unicorn_rails worker')
      end

      def t_resque_count
        process_count('resque')
      end

      def t_resque_count2
        process_count('resque.*Waiting for')
      end

      def t_memcached_count
        process_count('memcached')
      end

      def t_redis_count
        process_count('\bredis.*server\b')
      end

      def t_haproxy_count
        process_count("haproxy")
      end

      def t_git_count
        process_count('\bgit\b')
      end

      def t_sshd_count
        process_count('\bsshd\b')
      end

      def t_god_count
        process_count('\bgod\b')
      end

      def t_sleep
        # `sleep 2; date`
      end

      def ssh_login_canable?
        if @ssh_login_canable.nil?
          @ssh_login_canable = !!remote_run("hostname")
        end
        @ssh_login_canable
      end

      def z_uptime
        if ssh_login_canable?
          @uptime ||= remote_run("uptime")
        end
      end

      def process_count(match1)
        if ssh_login_canable?
          if pids = process_pids(match1)
            pids.size
          end
        end
      end

      def process_pids(match1)
        if t_inside_hostname
          remote_run("ps aux | grep -i '#{match1}' | grep -v grep | awk '{ print \\$2 }'").to_s.scan(/\d+/)
        end
      end

      def ssh_host
        if @host_info[:ssh]
          @host_info[:ssh]
        elsif @host_info[:user]
          [@host_info[:user], a_host].join("@")
        else
          a_host
        end
      end

      def remote_run(command)
        ssh_auth_sock_set
        @base.command_run(%(ssh #{ssh_host} "#{command}"))
      end

      def ssh_auth_sock_set
        unless ENV["SSH_AUTH_SOCK"]
          sock = `ls /tmp/launch-*/Listeners`.strip
          if sock.empty?
            raise ArgumentError, "SSHのソケットが見つかりません"
          end
          ENV["SSH_AUTH_SOCK"] = sock
          @base.logger_puts "SSH_AUTH_SOCK: #{sock}"
        end
      end
    end
  end
end

if $0 == __FILE__
  base = Mogrin::Core.new
  obj = Mogrin::Agent::HostAgent.new(base, :host => "localhost")
  obj.instance_eval do
    # ENV["SSH_AUTH_SOCK"] = nil
    # # ENV["SSH_AUTH_SOCK"] = `ls /tmp/launch-*/Listeners`.strip
    # p remote_run("hostname")
    p result
  end
end
