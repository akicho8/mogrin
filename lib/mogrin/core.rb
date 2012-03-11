# -*- coding: utf-8 -*-

require "active_support/core_ext/string"
require "active_support/core_ext/array"
require "active_support/buffered_logger"
require "rain_table"
require "open3"
require "tapp"

require_relative "agent"
require_relative "version"

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
        :timeout     => 16.0,
        :debug       => false,
        :quiet       => false,
        :skip_config => false,
        :append_log  => false,
        :single      => true,
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
      @alog = []
    end

    def run
      quiet{puts "#{File.basename($0)} #{VERSION}"}

      CONF_FILES.each{|conf_file|
        if f = self.class.conf_find(conf_file)
          if @config[:skip_config]
            quiet{puts "Skip: #{f}"}
          else
            quiet{puts "Load: #{f}"}
            instance_eval(f.read)
          end
        end
      }

      if f = @config[:file]
        f = Pathname(f)
        quiet{puts "Load: #{f}"}
        eval(f.read, binding)
      end

      if @args.empty?
        @args << "url"
        @args << "server"
      end

      Signal.trap(:INT) do
        unless @signal_interrupt
          @signal_interrupt = true
          puts "[BREAK]"
        end
      end

      @args.each do |task|
        "mogrin/#{task}_task".classify.constantize.new(self).execute
        if @signal_interrupt
          break
        end
      end

      if @config[:append_log]
        puts @alog
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

    def logger_puts(str)
      str = str.to_s.scan(/./).first(256).compact.join
      if @config[:debug]
        if @config[:append_log]
          @alog << str
        else
          puts str
        end
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
      stdout.encode!("utf-8", :invalid => :replace)
      stderr.encode!("utf-8", :invalid => :replace)
      if stdout.present?
        logger_puts "        out: #{stdout.inspect}"
      end
      if stderr.present?
        logger_puts "     err: #{stderr.inspect}"
      end
      stdout.presence
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
        sleep(0.001)
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

    private

    def agent_execute(klass, items)
      if @base.config[:single]
        items.each.with_index.collect{|item, index|
          @base.quiet{print "#{items.size - index} "}
          @base.int_block{klass.new(@base, item).result}
        }.compact
      else
        threads = items.each.with_index.collect{|item, index|
          @base.quiet{print "#{items.size - index} "}
          Thread.start{klass.new(@base, item).result}
        }.compact
        loop do
          if threads.none?{|t|t.alive?}
            break
          end
          if @base.signal_interrupt
            break
          end
          sleep 0.001
        end
        threads.each{|v|Thread.kill(v)}
        threads.each{|v|v.join}
        threads.collect(&:value).compact
      end
    end
  end

  class ServerTask < Task
    def execute
      rows = agent_execute(Agent::ServerAgent, @base.servers)
      if rows.present?
        @base.quiet{puts}
        puts RainTable.generate(rows){|options|
          options[:select] = [
            {:key => :s_desc,            :label => "用途",     :size => nil},
            {:key => :s_host,            :label => "鯖名",     :size => nil},
            {:key => :t_name2ip,         :label => "正引き",   :size => nil},
            {:key => :t_ip2name,         :label => "逆引き",   :size => 12},
            {:key => :t_inside_hostname, :label => "内側HN",   :size => nil},
            {:key => :t_loadavg,         :label => "AVG",      :size => nil},
            # {:key => :t_passenger_count, :label => "PSG",      :size => nil},
            {:key => :t_nginx_count,     :label => "NGX",      :size => nil},
            {:key => :t_unicorn_count,   :label => "UNC",      :size => nil},
            {:key => :t_resque_count,    :label => "RSQ",      :size => nil},
            {:key => :t_resque_count2,   :label => "RSW",      :size => nil},
            {:key => :t_redis_count,     :label => "RDS",      :size => nil},
            {:key => :t_memcached_count, :label => "MEC",      :size => nil},
            # {:key => :t_sleep,           :label => "SLEEP",    :size => nil},
          ]
        }
      end
    end
  end

  class UrlTask < Task
    def execute
      rows = agent_execute(Agent::UrlAgent, @base.urls)
      if rows.present?
        @base.quiet{puts}
        puts RainTable.generate(rows){|options|
          options[:select] = [
            {:key => :s_desc,             :label => "DESC",     :size => nil},
            {:key => :s_url,              :label => "URL",      :size => nil},
            {:key => :s_status,           :label => "RET",      :size => 6},
            {:key => :s_response_time,    :label => "反速",     :size => nil},
            {:key => :s_site_title,       :label => "Title",    :size => 8},
            {:key => :s_revision,         :label => "Ref",      :size => 7},
            {:key => :s_updated_at_s,     :label => "最終",     :size => 18},
            {:key => :t_commiter,         :label => "書人",     :size => 4},
            {:key => :t_before_days,      :label => "過時",     :size => nil},
            {:key => :t_pending_count,    :label => "PD",       :size => nil},
            # {:key => :s_x_runtime,        :label => "x-rt",     :size => 4},
            # {:key => :s_server,           :label => "鯖面",     :size => 4},
          ]
        }
      end
    end
  end

  class ListTask < Task
    def execute
      @base.urls.each{|info|
        puts "■#{info[:desc]}"
        puts "#{info[:url]}"
      }
      puts
      @base.servers.each{|info|
        puts "■#{info[:desc]}"
        puts "ssh #{info[:host]}"
      }
    end
  end
end

if $0 == __FILE__
  p "あ".encode
  p Encoding.default_internal

  Mogrin::Core.run{|obj|
    obj.args << "url"
    obj.config[:skip_config] = true
    obj.config[:append_log] = true
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
