# -*- coding: utf-8 -*-
require "active_support/core_ext/benchmark"
require "open-uri"
require "timeout"
require "resolv"

module Mogrin
  module Agent
    class Base
      def initialize(base)
        @base = base
      end

      def run
      end

      def result
        run
        attrs = {}
        if @base.config[:single]
          attrs.update(single_response(private_methods.grep(/\A([st]_)/)))
        else
          attrs.update(single_response(private_methods.grep(/\A(s_)/)))
          attrs.update(thread_response(private_methods.grep(/\A(t_)/)))
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
              @base.quiet{print "."}
              v = method_run(key)
              @base.quiet{print "."}
              v
            })
        }
        @base.logger_puts(threads.pretty_inspect)

        mark = nil
        begin
          Timeout::timeout(@base.config[:timeout]){
            loop do
              if threads.values.none?{|t|t.alive?}
                # @base.quiet{print "[SUCCESS]"}
                break
              end
              if @base.signal_interrupt
                @base.quiet{print "[SIGNAL BREAK JOIN]"}
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
        @base.logger_puts(threads.pretty_inspect)

        threads.values.each{|v|Thread.kill(v)}
        threads.values.each(&:join)

        threads.inject({}){|h, (key, t)|
          h.merge(key => t.value || mark)
        }
      end

      def method_run(key)
        begin
          v = send(key)
        rescue => error
          @base.logger_puts("#{key}: #{error.inspect} #{error.backtrace}")
          v = "E"
        end
        v
      end
    end
  end
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), "agent/*.rb"))].sort.each{|filename|require(filename)}
