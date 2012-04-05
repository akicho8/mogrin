# -*- coding: utf-8 -*-
require "active_support/core_ext/benchmark"
require "open-uri"
require "timeout"
require "resolv"

module Mogrin
  module Agent
    class Base
      def initialize(base, options = {})
        @base = base
        @options = {}
      end

      def run
      end

      def result
        run
        attrs = {}
        filter(private_methods.grep(/\A([a]_)/)).each{|key|attrs.update(key => send(key))}
        if @base.config[:single]
          attrs.update(single_response(filter(private_methods.grep(/\A([st]_)/))))
        else
          attrs.update(single_response(filter(private_methods.grep(/\A(s_)/))))
          attrs.update(thread_response(filter(private_methods.grep(/\A(t_)/))))
        end
      end

      def single_response(keys)
        keys.inject({}){|h, key|
          h.merge(key => method_run(key))
        }
      end

      def thread_response(keys)
        threads = keys.inject({}){|h, key|
          h.merge(key => Thread.start{
              method_run(key)
            })
        }
        thread_status(threads)

        mark = nil
        begin
          Timeout::timeout(@base.config[:timeout]){
            loop do
              if threads.values.none?{|t|t.alive?}
                break
              end
              if @base.signal_interrupt
                break
              end
              sleep 0.001
            end
          }
        rescue Timeout::Error => error
          mark = "T"
          @base.quiet{print "[TIMEOUT] "}
          @base.logger_puts(error)
        end
        thread_status(threads)

        threads.values.each{|v|Thread.kill(v)}
        threads.values.each(&:join)

        threads.inject({}){|h, (key, t)|
          h.merge(key => t.value || mark)
        }
      end

      def method_run(key)
        return if @base.config[:dry_run]
        begin
          v = send(key)
          @base.quiet{print "."}
        rescue => error
          @base.logger_puts("#{key}: #{error.inspect} #{error.backtrace}")
          @base.quiet{print "F"}
          v = "F"
        end
        v
      end

      def thread_status(threads)
        @base.logger_puts(threads.values.collect(&:status).pretty_inspect)
      end

      def filter(_methods)
        if @options[:command]
          _methods.find_all{|e|e.to_sym.include?(@options[:command])}
        else
          _methods
        end
      end
    end
  end
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), "agent/*.rb"))].sort.each{|filename|require(filename)}
