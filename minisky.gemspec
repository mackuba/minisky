# frozen_string_literal: true

require_relative "lib/minisky/version"

Gem::Specification.new do |spec|
  spec.name = "minisky"
  spec.version = Minisky::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "Write a short summary, because RubyGems requires one."
  spec.description = "Write a longer description or delete this line."
  spec.homepage = "https://github.com/mackuba/minisky"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/mackuba/minisky/issues",
    "changelog_uri"     => "https://github.com/mackuba/minisky/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/mackuba/minisky",
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]
end
