# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'polint/version'

Gem::Specification.new do |spec|
  spec.name          = "polint"
  spec.version       = Polint::VERSION
  spec.authors       = ["Julien Letessier", "Greg Beech"]
  spec.email         = ["julien.letessier@gmail.com", "greg@gregbeech.com"]
  spec.summary       = %q{A linter for Uniforum PO files.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "guard-rspec"

  spec.add_dependency "term-ansicolor"
  spec.add_dependency "parslet", "~> 1.8"
end
