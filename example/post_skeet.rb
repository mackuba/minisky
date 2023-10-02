#!/usr/bin/env ruby

# Example: make a new post (aka "skeet") with text passed in the argument to the script.
#
# Requires a bluesky.yml config file in the same directory with contents like this:
# id: your.handle
# pass: secretpass

# load minisky from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'minisky'

if ARGV[0].to_s.empty?
  puts "Usage: #{$PROGRAM_NAME} <text>"
  exit 1
end

text = ARGV[0]

# create a client instance
bsky = Minisky.new('bsky.social', File.join(__dir__, 'bluesky.yml'))

bsky.post_request('com.atproto.repo.createRecord', {
  repo: bsky.user.did,
  collection: 'app.bsky.feed.post',
  record: {
    text: text,
    langs: ["en"],
    createdAt: Time.now.iso8601
  }
})

puts "Posted ✓"
