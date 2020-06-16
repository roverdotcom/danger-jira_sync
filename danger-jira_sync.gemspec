# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jira_sync/gem_version.rb"

Gem::Specification.new do |spec|
  spec.name          = "danger-jira_sync"
  spec.version       = JiraSync::VERSION
  spec.authors       = ["Ben Menesini"]
  spec.email         = ["ben.menesini@rover.com"]
  spec.description   = "Synchronizes information between Jira and GitHub"
  spec.summary       = "Synchronizes information betweeh Jira and GitHub"
  spec.homepage      = "https://github.com/roverdotcom/danger-jira_sync"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "danger-plugin-api", "~> 1.0"
  spec.add_runtime_dependency "jira-ruby", "~> 1.5.0"
  spec.add_development_dependency "activesupport", "~> 5.2.4.3"

  # General ruby development
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "rake", "~> 10.0"

  # Testing support
  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"

  # Linting code and docs
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "yard", "~> 0.9.20"

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-rspec", "~> 4.7"

  # If you want to work on older builds of ruby
  spec.add_development_dependency "listen", "3.0.7"

  # Pretty print
  spec.add_development_dependency "awesome_print"

  # This gives you the chance to run a REPL inside your tests
  # via:
  #
  #    require 'pry'
  #    binding.pry
  #
  # This will stop test execution and let you inspect the results
  spec.add_development_dependency "pry"
end
