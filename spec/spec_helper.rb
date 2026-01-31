require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
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

module SimpleCov
  module Formatter
    class HTMLFormatter
      def format(result)
        # silence the stdout summary, just save the html files
        unless @inline_assets
          Dir[File.join(@public_assets_dir, "*")].each do |path|
            FileUtils.cp_r(path, asset_output_path, remove_destination: true)
          end
        end

        File.open(File.join(output_path, "index.html"), "wb") do |file|
          file.puts template("layout").result(binding)
        end
      end
    end
  end
end

INVALID_METHOD_NAMES = [
  'getUsers',
  '127.0.0.1',
  '/xrpc/com.atproto.repo.getRecords',
  'app.bsky.feed.under_score'
]
