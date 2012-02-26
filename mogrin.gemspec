Gem::Specification.new do |spec|
  spec.name = "mogrin"
  spec.version = "0.1.0"
  spec.summary = "shikatsu kanshi script"
  spec.author = "akicho8"
  spec.homepage = "http://github.com/akicho8/mogrin"
  spec.description = "shikatsu kanshi no script desuyo"
  spec.email = "akicho8@gmail.com"
  spec.files = %x[git ls-files].scan(/\S+/)
  spec.test_files = []
  spec.rdoc_options = ["--line-numbers", "--inline-source", "--charset=UTF-8", "--diagram", "--image-format=jpg"]
  spec.executables = ["mog"]
  spec.platform = Gem::Platform::RUBY
  spec.add_dependency("activesupport")
end
