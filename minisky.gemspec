# frozen_string_literal: true

require_relative "lib/minisky/version"

Gem::Specification.new do |spec|
  spec.name = "minisky"
  spec.version = Minisky::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "A minimal client of Bluesky/ATProto API"
  spec.description = "A very simple client class that lets you log in to the Bluesky API and make any requests there."
  spec.homepage = "https://ruby.sdk.blue"

  spec.license = "Zlib"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri"   => "https://tangled.org/mackuba.eu/minisky/issues",
    "changelog_uri"     => "https://tangled.org/mackuba.eu/minisky/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://tangled.org/mackuba.eu/minisky",
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'base64', '~> 0.1'
end
