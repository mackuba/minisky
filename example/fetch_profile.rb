#!/usr/bin/env ruby

# Example: fetch profile info of a given user and their last 10 posts (excluding reposts).
#
# This script connects to the AppView server at api.bsky.app, which allows calling such
# endpoints as getProfile or getAuthorFeed without authentication.

# load minisky from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'minisky'
require 'time'

if ARGV[0].to_s !~ /^@?[\w\-]+(\.[\w\-]+)+$/
  puts "Usage: #{$PROGRAM_NAME} <handle>"
  exit 1
end

handle = ARGV[0].gsub(/^@/, '')

# passing nil as config file to use an unauthenticated client
bsky = Minisky.new('api.bsky.app', nil)

# fetch profile info
profile = bsky.get_request('app.bsky.actor.getProfile', { actor: handle })

# fetch posts, without replies - we fetch a bit more than we need because we'll also
# filter out reposts
posts = bsky.get_request('app.bsky.feed.getAuthorFeed', {
  actor: handle,
  filter: 'posts_no_replies',
  limit: 40
})

# print the profile

puts
puts "====[ @#{handle} • #{profile['displayName']} • #{profile['did']} ]===="
puts
puts profile['description']
puts
puts '=' * 80
puts

# print the posts

posts['feed'].map { |r|
  r['post']
}.select { |p|
  # select only posts from this account
  p['author']['handle'] == handle
}.slice(0, 10).each { |p|
  time = Time.parse(p['record']['createdAt'])
  timestamp = time.getlocal.strftime('%a %d.%m %H:%M')

  puts "#{timestamp}: #{p['record']['text']}"
  puts
}
