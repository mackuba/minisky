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

# to make a post, we upload a post record to the posts collection (app.bsky.feed.post) in the user's repo

bsky.post_request('com.atproto.repo.createRecord', {
  repo: bsky.user.did,
  collection: 'app.bsky.feed.post',
  record: {
    text: text,
    createdAt: Time.now.iso8601,  # we need to set the date to current time manually
    langs: ["en"]   # if a post does not have a language set, it may be autodetected as an incorrect language
  }
})

puts "Posted ✓"
