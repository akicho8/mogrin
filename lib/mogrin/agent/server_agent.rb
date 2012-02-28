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
      rescue => error
        error
      end

      def c_ip2name
        Resolv.getname(Resolv.getaddresses(c_host).first)
      rescue => error
        error
      end

      def c_inside_hostname
        remote_run("hostname")
      end

      def c_loadavg
        remote_run("uptime"){|str|
          # ["16:41", "up", "4", "days,", "14:40,", "4", "users,", "load", "averages:", "0.89", "0.62", "0.58"]
          #                                                                                     ^^^^^^
          str.split(/[,\s]+/)[-2]
        }
      end

      def c_passenger_count
        process_count_for("passenger")
      end

      def c_nginx_count
        process_count_for("nginx")
      end

      def c_unicorn_count
        process_count_for("unicorn")
      end

      def c_resque_count
        process_count_for("resque")
      end

      def c_memcached_count
        process_count_for("memcached")
      end

      def c_redis_count
        process_count_for("redis")
      end

      def process_count_for(name)
        remote_run("ps aux | grep -i #{name} | grep -v grep").lines.count
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
        begin
          str = Timeout.timeout(@base.config[:timeout]) do
            @base.command_run(%(ssh #{ssh_server} "#{command}"))
          end

          if block_given?
            yield str
          else
            str
          end
        rescue => error
          @base.logger_puts("ERROR: #{error.inspect}")
          error
        end
      end
    end
  end
end
