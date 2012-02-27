require "active_support/core_ext/benchmark"
require "open-uri"
require "timeout"
require "resolv"
require "net/ssh"

module Mogrin
  class Agent
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
