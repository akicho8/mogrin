# -*- coding: utf-8 -*-

require "active_support/core_ext/string"
require "active_support/core_ext/array"
require "active_support/buffered_logger"
require "rain_table"
require "open3"
require "tapp"

require_relative "agent"
require_relative "server_agent"
require_relative "url_agent"

module Mogrin
  class Core
    CONF_FILES = [
      "config/mogrin.rb",
      "config/.mogrin",
      "config/.mogrin.rb",
      ".mogrin",
      ".mogrin.rb",
    ]

    def self.run(*args)
      new(*args).run
    end

    def self.conf_find(basename)
      basename = Pathname(basename)
      file = nil

      if basename.exist?
        return basename
      end

      dir = Pathname.pwd
      loop do
        f = dir + basename
        if f.exist?
          file = f
          break
        end
        dir = dir.parent
        if dir.root?
          break
        end
      end

      file
    end

    def self.default_config
      {
        :timeout     => 3.0,
        :debug       => false,
        :quiet       => false,
        :skip_config => false,
      }
    end

    attr_accessor :config

    def initialize(args = [], config = {}, &block)
      @args = args
      @config = self.class.default_config.merge(config)
      if block
        yield @config
      end
    end

    def run
      CONF_FILES.each{|conf_file|
        if f = self.class.conf_find(conf_file)
          if @config[:skip_config]
            quiet{puts "Skip: #{f}"}
          else
            quiet{puts "AutoLoad: #{f}"}
            instance_eval(f.read)
          end
        end
      }

      if f = @config[:file]
        f = Pathname(f)
        quiet{puts "DirectLoad: #{f}"}
        eval(f.read, binding)
      end

      if @args.empty?
        @args << "url"
        @args << "server"
      end

      @args.each{|task|
        public_send("#{task}_task")
      }
    end

    def servers
      if @config[:servers]
        @config[:servers]
      else
        [
          {:host => "localhost"},
        ]
      end
    end

    def urls
      if @config[:urls]
        @config[:urls]
      else
        [
          {:url => "http://localhost/"},
          {:url => "http://www.google.co.jp/"},
        ]
      end
    end

    def filter(items, keys)
      if @config[:match]
        items.find_all{|item|
          keys.any?{|key|
            if s = item[key]
              s.match(/#{@config[:match]}/i)
            end
          }
        }
      else
        items
      end
    end

    def server_task
      items = servers
      items = filter(items, [:desc, :host])
      rows = items.enum_for(:each_with_index).collect{|item, index|
        quiet{print "#{items.size - index} "}
        ServerAgent.new(self, item).result
      }
      quiet{puts}
      puts RainTable.generate(rows){|options|
        options[:select] = [
          {:key => :c_desc,            :label => "用途",     :size => nil},
          {:key => :c_host,            :label => "鯖名",     :size => nil},
          {:key => :c_name2ip,         :label => "正引き",   :size => nil},
          {:key => :c_ip2name,         :label => "逆引き",   :size => 20},
          {:key => :c_inside_hostname, :label => "内側HN",   :size => nil},
          {:key => :c_loadavg,         :label => "LAVG",     :size => nil},
          {:key => :c_passenger_count, :label => "PSG",      :size => nil},
          {:key => :c_nginx_count,     :label => "NGX",      :size => nil},
          {:key => :c_unicorn_count,   :label => "UNC",      :size => nil},
          {:key => :c_resque_count,    :label => "RSQ",      :size => nil},
          {:key => :c_redis_count,     :label => "RDS",      :size => nil},
          {:key => :c_memcached_count, :label => "MEC",      :size => nil},
        ]
      }
    end

    def url_task
      items = urls
      items = filter(items, [:desc, :url])
      rows = items.enum_for(:each_with_index).collect{|item, index|
        quiet{print "#{items.size - index} "}
        UrlAgent.new(self, item).result
      }
      quiet{puts}
      puts RainTable.generate(rows){|options|
        options[:select] = [
          {:key => :c_desc,             :label => "用途",     :size => nil},
          {:key => :c_url,              :label => "URL",      :size => nil},
          {:key => :c_status,           :label => "状態",     :size => 6},
          {:key => :c_revision,         :label => "Rev",      :size => 7},
          {:key => :c_updated_at_s,     :label => "最終",     :size => 18},
          {:key => :c_commiter,         :label => "書人",     :size => 4},
          {:key => :c_before_days,      :label => "経過",     :size => nil},
          {:key => :c_pending_count,    :label => "PE",       :size => nil},
          {:key => :c_site_title,       :label => "タイトル", :size => 8},
          # {:key => :c_x_runtime,        :label => "x-rt",     :size => 4},
          {:key => :c_response_time,    :label => "反射",     :size => nil},
          # {:key => :c_server,           :label => "鯖面",     :size => 4},
        ]
      }
    end

    def list_task
      pp servers
      pp urls
    end

    def logger
      if @config[:debug]
        @logger ||= ActiveSupport::BufferedLogger.new(STDOUT)
      end
    end

    def logger_puts(str)
      if logger
        logger.info(str)
      end
    end

    def quiet
      unless @config[:quiet]
        yield
      end
    end

    def command_run(command)
      logger_puts("RUN: #{command}")
      stdout, stderr = Open3.popen3(command){|stdin, stdout, stderr|[stdout.read.strip, stderr.read.strip]}
      if stdout.present?
        logger_puts("STDOUT: #{stdout.inspect}")
      end
      if stderr.present?
        logger_puts("ERROR: #{stderr.inspect}")
      end
      stdout
    end
  end
end

if $0 == __FILE__
  Mogrin::Core.run
end
