require_relative "mogrin/core"

module Mogrin
  VERSION = "0.1.0"
end

if $0 == __FILE__
  Mogrin::Core.run(["url"])
  Mogrin::Core.run(["server"])
end
