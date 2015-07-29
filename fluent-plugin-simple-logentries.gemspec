# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-simple-logentries"
  spec.version       = "0.0.1"
  spec.description   = "Push fluent events to Logentries"
  spec.authors       = ["sowawa"]
  spec.email         = ["kesiuke.sogawa@gmail.com"]
  spec.summary       = "Logentries output plugin for Fluent event collector"
  spec.homepage      = "https://github.com/sowawa/fluent-plugin-simple-logentries"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency 'rake', '~> 0'
end
