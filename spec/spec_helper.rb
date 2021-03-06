# frozen_string_literal: true

require "pathname"
ROOT = Pathname.new(File.expand_path("..", __dir__))
$:.unshift((ROOT + "lib").to_s)
$:.unshift((ROOT + "spec").to_s)

require "bundler/setup"
require "pry"

require "dotenv"
Dotenv.load

# Must be required and started before danger
require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "rspec"
require "danger"
require "webmock"
require "webmock/rspec"
require "vcr"

if `git remote -v` == ""
  puts "You cannot run tests without setting a local git remote on this repo"
  puts "It's a weird side-effect of Danger's internals."
  exit(0)
end

# Use coloured output, it's the best.
RSpec.configure do |config|
  config.filter_gems_from_backtrace "bundler"
  config.color = true
  config.tty = true
end

VCR.configure do |config|
  config.cassette_library_dir = "#{File.dirname(__FILE__)}/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<GITHUB_TOKEN>") { ENV["DANGER_GITHUB_API_TOKEN"] }
  config.filter_sensitive_data("<JIRA_URL>") { ENV["DANGER_JIRA_URL"] }
  config.filter_sensitive_data("<JIRA_USER>") { ENV["DANGER_JIRA_USERNAME"] }
  config.filter_sensitive_data("<JIRA_PASS>") { ENV["DANGER_JIRA_API_TOKEN"] }

  config.before_record do |interaction|
    interaction.response.headers.delete("Set-Cookie")
    interaction.request.headers.delete("Authorization")
  end
end

require "danger_plugin"

# These functions are a subset of https://github.com/danger/danger/blob/master/spec/spec_helper.rb
# If you are expanding these files, see if it's already been done ^.

# A silent version of the user interface,
# it comes with an extra function `.string` which will
# strip all ANSI colours from the string.

# rubocop:disable Lint/NestedMethodDefinition
def testing_ui
  @output = StringIO.new
  def @output.winsize
    [20, 9999]
  end

  cork = Cork::Board.new(out: @output)
  def cork.string
    out.string.gsub(/\e\[([;\d]+)?m/, "")
  end
  cork
end
# rubocop:enable Lint/NestedMethodDefinition

# Example environment (ENV) that would come from
# running a PR on TravisCI
def testing_env
  {
    "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true",
    "TRAVIS_PULL_REQUEST" => "800",
    "TRAVIS_REPO_SLUG" => "artsy/eigen",
    "TRAVIS_COMMIT_RANGE" => "759adcbd0d8f...13c4dc8bb61d",
    "DANGER_GITHUB_API_TOKEN" => ENV["DANGER_GITHUB_API_TOKEN"],
    "DANGER_JIRA_URL" => ENV["DANGER_JIRA_URL"],
    "DANGER_JIRA_USERNAME" => ENV["DANGER_JIRA_USERNAME"],
    "DANGER_JIRA_API_TOKEN" => ENV["DANGER_JIRA_API_TOKEN"]
  }
end

# A stubbed out Dangerfile for use in tests
def testing_dangerfile
  env = Danger::EnvironmentManager.new(testing_env)
  Danger::Dangerfile.new(env, testing_ui)
end
