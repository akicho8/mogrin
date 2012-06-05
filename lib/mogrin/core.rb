# -*- coding: utf-8 -*-

require "active_support/core_ext/string"
require "active_support/core_ext/array"
require "active_support/buffered_logger"
require "active_support/core_ext/object/inclusion"
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
    TASKS = [:url, :host, :list]

    def self.run(*args, &block)
      new(*args, &block).run
    end

    def self.look_for_default_conf(basename)
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
        :timeout      => 16.0,
        :debug        => false,
        :quiet        => false,
        :skip_config  => false,
        :append_log   => false,
        :single       => true,
        :default_task => :url,
        :url          => nil,
        :host         => nil,
        :local        => false,
        :dry_run      => false,
        :pretty       => :full,
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
        if f = self.class.look_for_default_conf(conf_file)
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

      @tasks = @args

      # 曖昧な引数を自動解釈する実験
      if true
        urls = @tasks.find_all{|arg|arg.match(/^h?ttps?:/)}
        hosts = @tasks - urls - TASKS.collect(&:to_s)
        @tasks -= urls + hosts
        unless urls.empty?
          @config[:url] = urls.join(",")
          @tasks << "url"
        end
        unless hosts.empty?
          @config[:host] = hosts.join(",")
          @tasks << "host"
        end
        @tasks.uniq!
      end

      if @tasks.empty?
        @tasks += Array.wrap(@config[:default_task])
      end

      Signal.trap(:INT) do
        unless @signal_interrupt
          @signal_interrupt = true
          puts "[BREAK]"
        end
      end

      @tasks.each do |task|
        "mogrin/#{task}_task".classify.constantize.new(self).execute
        if @signal_interrupt
          break
        end
      end

      if @config[:append_log]
        puts @alog
      end
    end

    def hosts
      if @config[:host]
        items = @config[:host].split(",").collect{|str|{:host => str}}
      elsif @config[:local]
        items = {:host => "localhost"}
      else
        items = @config[:hosts]
        if @config[:servers]
          STDERR.puts "DEPRECATION: @config[:servers]"
          items ||= @config[:servers]
        end
      end
      filter(items, [:desc, :host])
    end

    def urls
      if @config[:url]
        items = @config[:url].split(",").collect{|str|{:url => normalize_url(str)}}
      elsif @config[:local]
        items = [{:url => "http://localhost:3000/"}]
      else
        items = @config[:urls]
      end
      filter(items, [:desc, :url])
    end

    def filter(items, keys)
      items = Array.wrap(items)
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
      str = str.to_s.scan(/./).first(128).compact.join
      if @config[:debug]
        if @config[:append_log]
          @alog << str
        else
          puts str
        end
      end
    end

    def quiet
      return if @config[:quiet]
      yield
    end

    def command_run(command)
      logger_puts "command_run: #{command}"
      stdout, stderr = Open3.popen3(command){|stdin, stdout, stderr|[stdout.read.strip, stderr.read.strip]}
      stdout.encode!("utf-8", :invalid => :replace)
      stderr.encode!("utf-8", :invalid => :replace)
      if stdout.present?
        logger_puts "     out: #{stdout.inspect}"
      end
      if stderr.present?
        logger_puts "     err: #{stderr.inspect}"
      end
      stdout.presence
    end

    def int_block(&block)
      return if @signal_interrupt
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

    def normalize_url(url)
      url = url.to_s.strip
      if url.match(/^h?ttps?:/)
        url
      else
        url = "http://#{url}"
      end
      URI(url).normalize.to_s
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

    def agent_execute(klass, items, options = {})
      if @base.config[:single]
        items.each.with_index.collect{|item, index|
          @base.quiet{print "#{items.size - index} "}
          @base.int_block{klass.new(@base, item, options).result}
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

  class HostTask < Task
    def execute
      commands = select_fields.collect{|e|e[:key]}
      rows = agent_execute(Agent::HostAgent, @base.hosts, :commands => commands)
      if rows.present?
        @base.quiet{puts}
        puts RainTable.generate(rows, :select => select_fields)
      end
    end

    def select_fields
      select = []
      select << {:key => :a_desc,            :label => "用途",     :size => nil}
      select << {:key => :a_host,            :label => "鯖名",     :size => nil}
      if @base.config[:pretty].to_s.in?(["full", "dns"])
        select << {:key => :t_name2ip,         :label => "正引き",   :size => nil}
        select << {:key => :t_ip2name,         :label => "逆引き",   :size => 12}
        select << {:key => :t_inside_hostname, :label => "内側HN",   :size => nil}
      end
      if @base.config[:pretty].to_s.in?(["full", "process", "ssh"])
        select << {:key => :t_loadavg,         :label => "LAVG",     :size => nil, :padding => 0}
        select << {:key => :t_uptime,          :label => "UP",       :size => nil, :padding => 0}
        select << {:key => :t_pid_count,       :label => "IDS",      :size => nil, :padding => 0}
        select << {:key => :t_nginx_count,     :label => "NGX",      :size => nil, :padding => 0}
        select << {:key => :t_nginx_count2,    :label => "NGS",      :size => nil, :padding => 0}
        select << {:key => :t_unicorn_count,   :label => "UCN",      :size => nil, :padding => 0}
        select << {:key => :t_unicorn_count2,  :label => "UCS",      :size => nil, :padding => 0}
        select << {:key => :t_resque_count,    :label => "RSQ",      :size => nil, :padding => 0}
        select << {:key => :t_resque_count2,   :label => "RSW",      :size => nil, :padding => 0}
        select << {:key => :t_redis_count,     :label => "RDS",      :size => nil, :padding => 0}
        select << {:key => :t_haproxy_count,   :label => "PRX",      :size => nil, :padding => 0}
        select << {:key => :t_memcached_count, :label => "MEM",      :size => nil, :padding => 0}
        select << {:key => :t_git_count,       :label => "Git",      :size => nil, :padding => 0}
        select << {:key => :t_sshd_count,      :label => "SSH",      :size => nil, :padding => 0}
        select << {:key => :t_god_count,       :label => "GOD",      :size => nil, :padding => 0}
      end
      # select << {:key => :t_sleep,           :label => "SLEEP",    :size => nil}
      # case @base.config[:pretty].to_s
      # when "short"
      #   select.reject!{|e|e[:key].in?([:t_name2ip, :t_ip2name, :t_inside_hostname])}
      # when "medium"
      #   select.reject!{|e|e[:key].in?([:t_name2ip, :t_ip2name, :t_inside_hostname])}
      # end
      select
    end
  end

  class UrlTask < Task
    def execute
      rows = agent_execute(Agent::UrlAgent, @base.urls)
      if rows.present?
        @base.quiet{puts}
        puts RainTable.generate(rows){|options|
          options[:select] = [
            {:key => :a_desc,             :label => "DESC",   :size => nil},
            {:key => :a_url,              :label => "URL",    :size => 60},
            {:key => :s_status,           :label => "RET",    :size => 6},
            {:key => :s_response_time,    :label => "反速",   :size => nil},
            {:key => :s_site_title,       :label => "Title",  :size => 6},
            {:key => :s_ct,               :label => "Type",   :size => 4},
            {:key => :s_revision,         :label => "Ref",    :size => 7},
            {:key => :s_updated_at_s,     :label => "最終",   :size => nil},
            {:key => :t_commiter,         :label => "書",     :size => 3},
            {:key => :t_before_days,      :label => "過",     :size => nil},
            {:key => :t_pending_count,    :label => "PD",     :size => nil},
            # {:key => :s_x_runtime,        :label => "x-rt", :size => 4},
            # {:key => :a_host,           :label => "鯖面",   :size => 4},
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
      @base.hosts.each{|info|
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

    obj.args = ["host"]
    obj.config[:skip_config] = true
    obj.config[:debug] = true
    obj.config[:hosts] = [
      {:host => "localhost"},
    ]
  }
end
