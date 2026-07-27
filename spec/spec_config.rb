unless ENV["GITHUB_ACTIONS"] == "true"
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    formatter SimpleCov::Formatter::HTMLFormatter.new(silent: true)
  end
end

require 'minisky'
require 'pp' # needs to be included before fakefs
require 'fakefs/spec_helpers'
require 'webmock/rspec'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
