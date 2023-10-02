#!/usr/bin/env ruby

# Example: load last 10 posts from the "What's Science" feed and print the post text, data and author handle to the
# terminal. Does not require any authentication.
#
# It's definitely not the most efficient way to do this, but it demonstrates how to load single records from the API.

# load minisky from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'minisky'
require 'time'

# the "What's Science" custom feed by @bossett.bsky.social
# the service host is hardcoded here, ideally you should fetch the feed record and read the hostname from there
FEED_HOST = "bs.bossett.io"
FEED_URI = "at://did:plc:jfhpnnst6flqway4eaeqzj2a/app.bsky.feed.generator/for-science"

# fetch the feed from the feed server (getFeedSkeleton returns only a list or URIs of posts)
# pass nil as the config file parameter to create an unauthenticated client
feed_api = Minisky.new(FEED_HOST, nil)
feed = feed_api.get_request('app.bsky.feed.getFeedSkeleton', { feed: FEED_URI, limit: 10 })

# second client instance for the Bluesky API - again, pass nil to use without authentication
bsky = Minisky.new('bsky.social', nil)

# for each post URI, fetch the post record and the profile of its author
entries = feed['feed'].map do |r|
  # AT URI is always: at://<did>/<collection>/<rkey>
  did, collection, rkey = r['post'].gsub('at://', '').split('/')

  print '.'
  post = bsky.get_request('com.atproto.repo.getRecord', { repo: did, collection: collection, rkey: rkey })
  author = bsky.get_request('com.atproto.repo.describeRepo', { repo: did })

  [post, author]
end

puts

entries.each do |post, author|
  handle = author['handle']
  timestamp = Time.parse(post['value']['createdAt']).getlocal
  link = "https://bsky.app/profile/#{handle}/post/#{post['uri'].split('/').last}"

  puts "@#{handle} • #{timestamp} • #{link}"
  puts
  puts post['value']['text']
  puts
  puts "=" * 120
  puts
end
