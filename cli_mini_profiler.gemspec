# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cli_mini_profiler/version'

Gem::Specification.new do |spec|
  spec.name          = "cli_mini_profiler"
  spec.version       = CliMiniProfiler::VERSION
  spec.authors       = ["Keenan Brock"]
  spec.email         = ["keenan@thebrocks.net"]

  spec.summary       = %q{Utility to view and run rack-mini-profiler from the CLI}
  spec.description   = %q{Utility to view and run rack-mini-profiler from the CLI}
  spec.homepage      = "https://github.com/kbrock/cli_mini_profiler"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency     "activesupport"
  spec.add_runtime_dependency     "rack-mini-profiler"
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
