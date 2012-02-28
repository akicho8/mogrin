require "active_support/core_ext/benchmark"
require "open-uri"
require "timeout"
require "resolv"
require "net/ssh"

module Mogrin
  module Agent
    class Base
      def initialize(base)
        @base = base
      end

      def result
        private_methods.grep(/\A(c_)/).inject({}){|h, key|
          begin
            v = send(key)
          rescue => error
            @base.logger_puts("#{key}: #{error.inspect}")
            v = error.inspect
          end
          h.merge(key => v)
        }
      end
    end
  end
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), "agent/*.rb"))].sort.each{|filename|require(filename)}
