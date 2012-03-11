require_relative "mogrin/core"

if $0 == __FILE__
  Mogrin::Core.run(["url"])
  Mogrin::Core.run(["server"])
end
