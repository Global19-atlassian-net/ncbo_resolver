# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ncbo_resolver/version'

Gem::Specification.new do |spec|
  spec.name          = "ncbo_resolver"
  spec.version       = NCBO::Resolver::VERSION
  spec.authors       = ["Paul R Alexander"]
  spec.email         = ["palexander@stanford.edu"]
  spec.description   = %q{This gem resolves old system ids with new ones}
  spec.summary       = %q{This gem resolves old system ids with new ones}
  spec.homepage      = "http://github.com/ncbo/ncbo_resolver"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "progressbar"
  spec.add_development_dependency "redis"
  spec.add_development_dependency "recursive-open-struct"
end
