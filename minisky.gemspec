# frozen_string_literal: true

require_relative "lib/minisky/version"

Gem::Specification.new do |spec|
  spec.name = "minisky"
  spec.version = Minisky::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "A minimal client of Bluesky/AtProto API"
  spec.description = "A very simple client class that lets you log in to the Bluesky API and make any requests there."
  spec.homepage = "https://github.com/mackuba/minisky"

  spec.license = "Zlib"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/mackuba/minisky/issues",
    "changelog_uri"     => "https://github.com/mackuba/minisky/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/mackuba/minisky",
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['example/*.rb'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'base64', '~> 0.1'
  spec.add_dependency 'json', '~> 2.5'
  spec.add_dependency 'net-http', '~> 0.2'
  spec.add_dependency 'time', '~> 0.3'
  spec.add_dependency 'yaml', '~> 0.1'
end
