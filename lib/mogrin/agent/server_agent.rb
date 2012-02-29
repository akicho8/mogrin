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

      def c_desc
        @server_info[:desc]
      end

      def c_host
        @server_info[:host]
      end

      def c_name2ip
        Resolv.getaddresses(c_host).flatten.join(" ")
      end

      def c_ip2name
        Resolv.getname(Resolv.getaddresses(c_host).first)
      end

      def c_inside_hostname
        remote_run("hostname")
      end

      # ["16:41", "up", "4", "days,", "14:40,", "4", "users,", "load", "averages:", "0.89", "0.62", "0.58"]
      #                                                                                     ^^^^^^
      def c_loadavg
        remote_run("uptime").split(/[,\s]+/)[-2]
      end

      def c_passenger_count
        process_count("passenger")
      end

      def c_nginx_count
        process_count("nginx")
      end

      def c_unicorn_count
        process_count("unicorn")
      end

      def c_resque_count
        process_count("resque")
      end

      def c_memcached_count
        process_count("memcached")
      end

      def c_redis_count
        process_count("redis")
      end

      def process_count(name)
        process_pids(name).size
      end

      def process_pids(name)
        remote_run("ps aux | grep -i #{name} | grep -v grep | awk '{ $2 }'").squish
      end

      def ssh_server
        if @server_info[:ssh]
          @server_info[:ssh]
        elsif @server_info[:user]
          [@server_info[:user], c_host].join("@")
        else
          c_host
        end
      end

      def remote_run(command)
        @base.command_run(%(ssh #{ssh_server} "#{command}"))
      end
    end
  end
end

if $0 == __FILE__
  base = Mogrin::Core.new
  obj = Mogrin::Agent::ServerAgent.new(base, :host => "localhost")
  obj.instance_eval do
    p remote_run("hostname")
    p result
  end
end
