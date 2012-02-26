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
        h.merge(key => send(key))
      }
    end
  end
end
