# -*- coding: utf-8 -*-
if $0 == __FILE__
  require "../../mogrin"
end

module Mogrin
  module Agent
    class ServerAgent < Base
      def initialize(base, server_info)
        super(base)
        @server_info = server_info
      end

      private

      def s_desc
        @server_info[:desc]
      end

      def s_host
        @server_info[:host]
      end

      def t_name2ip
        @t_name2ip ||= Resolv.getaddress(s_host)
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
        if s = remote_run("uptime")
          s.split(/[,\s]+/)[-2]
        end
      end

      def t_passenger_count
        process_count("passenger")
      end

      def t_nginx_count
        process_count("nginx")
      end

      def t_unicorn_count
        process_count("unicorn")
      end

      def t_resque_count
        process_count("resque")
      end

      def t_resque_count2
        process_count("resque.*waiting.*for")
      end

      def t_memcached_count
        process_count("memcached")
      end

      def t_redis_count
        process_count("redis")
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

      def process_count(name)
        if ssh_login_canable?
          if pids = process_pids(name)
            pids.size
          end
        end
      end

      def process_pids(name)
        if t_inside_hostname
          remote_run("ps aux | grep -i '#{name}' | grep -v grep | awk '{ print \\$2 }'").to_s.scan(/\d+/)
        end
      end

      def ssh_server
        if @server_info[:ssh]
          @server_info[:ssh]
        elsif @server_info[:user]
          [@server_info[:user], s_host].join("@")
        else
          s_host
        end
      end

      def remote_run(command)
        ssh_auth_sock_set
        @base.command_run(%(ssh #{ssh_server} "#{command}"))
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
  obj = Mogrin::Agent::ServerAgent.new(base, :host => "localhost")
  obj.instance_eval do
    # ENV["SSH_AUTH_SOCK"] = nil
    # # ENV["SSH_AUTH_SOCK"] = `ls /tmp/launch-*/Listeners`.strip
    # p remote_run("hostname")
    p result
  end
end
