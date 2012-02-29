# -*- coding: utf-8 -*-

require "active_support/core_ext/string"
require "active_support/core_ext/array"
require "active_support/buffered_logger"
require "rain_table"
require "open3"
require "tapp"

require_relative "agent"

module Mogrin
  class Core
    CONF_FILES = [
      "config/mogrin.rb",
      "config/.mogrin",
      "config/.mogrin.rb",
      ".mogrin",
      ".mogrin.rb",
    ]

    def self.run(*args, &block)
      new(*args, &block).run
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

    attr_accessor :config, :args
    attr_reader :signal_interrupt

    def initialize(args = [], config = {}, &block)
      @args = args
      @config = self.class.default_config.merge(config)
      if block
        yield self
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

      Signal.trap(:INT) do
        @signal_interrupt = true
        puts "[BREAK]"
      end

      @args.each do |task|
        "mogrin/#{task}_task".classify.safe_constantize.new(self).execute
        if @signal_interrupt
          break
        end
      end
    end

    def servers
      if @config[:servers]
        items = @config[:servers]
      else
        items = [
          {:host => "localhost"},
        ]
      end
      filter(items, [:desc, :host])
    end

    def urls
      if @config[:urls]
        items = @config[:urls]
      else
        items = [
          {:url => "http://localhost/"},
          {:url => "http://www.google.co.jp/"},
        ]
      end
      filter(items, [:desc, :url])
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
      logger_puts "command_run: #{command}"
      stdout, stderr = Open3.popen3(command){|stdin, stdout, stderr|[stdout.read.strip, stderr.read.strip]}
      if stdout.present?
        logger_puts "  stdout: #{stdout.inspect}"
      end
      if stderr.present?
        logger_puts "  stderr: #{stderr.inspect}"
      end
      stdout
    end

    def int_block(&block)
      if @signal_interrupt
        return
      end
      t = Thread.start(&block)
      while t.alive?
        if @signal_interrupt
          t.kill
          return
        end
        sleep(0.1)
      end
      t.value
    end
  end

  class Task
    def initialize(base)
      @base = base
    end

    def execute
      raise NotImplementedError, "#{__method__} is not implemented"
    end
  end

  class ServerTask < Task
    def execute
      items = @base.servers
      rows = items.enum_for(:each_with_index).collect{|item, index|
        @base.quiet{print "#{items.size - index} "}
        @base.int_block{Agent::ServerAgent.new(@base, item).result}
      }.compact
      if rows.present?
        @base.quiet{puts}
        puts RainTable.generate(rows){|options|
          options[:select] = [
            {:key => :c_desc,            :label => "用途",     :size => nil},
            {:key => :c_host,            :label => "鯖名",     :size => nil},
            {:key => :c_name2ip,         :label => "正引き",   :size => nil},
            {:key => :c_ip2name,         :label => "逆引き",   :size => 12},
            {:key => :c_inside_hostname, :label => "内側HN",   :size => nil},
            {:key => :c_loadavg,         :label => "AVG",      :size => nil},
            # {:key => :c_passenger_count, :label => "PSG",      :size => nil},
            {:key => :c_nginx_count,     :label => "NGX",      :size => nil},
            {:key => :c_unicorn_count,   :label => "UNC",      :size => nil},
            {:key => :c_resque_count,    :label => "RSQ",      :size => nil},
            {:key => :c_redis_count,     :label => "RDS",      :size => nil},
            {:key => :c_memcached_count, :label => "MEC",      :size => nil},
          ]
        }
      end
    end
  end

  class UrlTask < Task
    def execute
      items = @base.urls
      rows = items.enum_for(:each_with_index).collect{|item, index|
        @base.quiet{print "#{items.size - index} "}
        @base.int_block{Agent::UrlAgent.new(@base, item).result}
      }.compact
      if rows.present?
        @base.quiet{puts}
        puts RainTable.generate(rows){|options|
          options[:select] = [
            {:key => :c_desc,             :label => "用途",     :size => nil},
            {:key => :c_url,              :label => "URL",      :size => nil},
            {:key => :c_status,           :label => "状態",     :size => 6},
            {:key => :c_revision,         :label => "Rev",      :size => 4},
            {:key => :c_updated_at_s,     :label => "最終",     :size => 18},
            {:key => :c_commiter,         :label => "書人",     :size => 4},
            {:key => :c_before_days,      :label => "古",       :size => nil},
            {:key => :c_pending_count,    :label => "PE",       :size => nil},
            {:key => :c_site_title,       :label => "タイトル", :size => 8},
            # {:key => :c_x_runtime,        :label => "x-rt",     :size => 4},
            {:key => :c_response_time,    :label => "反応",     :size => nil},
            # {:key => :c_server,           :label => "鯖面",     :size => 4},
          ]
        }
      end
    end
  end

  class ListTask < Task
    def execute
      pp @base.servers
      @base.urls.each{|info|
        puts "■#{info[:desc]}"
        puts "#{info[:url]}"
      }
    end
  end
end

if $0 == __FILE__
  Mogrin::Core.run{|obj|
    obj.args << "url"
    obj.config[:skip_config] = true
    obj.config[:debug] = true
    obj.config[:urls] = [
      {:url => "http://www.nicovideo.jp/"},
    ]

    obj.args = ["server"]
    obj.config[:skip_config] = true
    obj.config[:debug] = true
    obj.config[:servers] = [
      {:host => "localhost"},
    ]
  }
end
