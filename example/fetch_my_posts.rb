#!/usr/bin/env ruby

# Example: sync all posts from your account (excluding replies and reposts) to a local
# JSON file. When run again, it will only fetch new posts since the last time and
# append them to the file.
#
# Requires a bluesky.yml config file in the same directory with contents like this:
# id: your.handle
# pass: secretpass

# load minisky from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'minisky'

CONFIG_FILE = File.join(__dir__, 'bluesky.yml')
POSTS_FILE = File.join(__dir__, 'posts.json')

# create a client instance
bsky = Minisky.new('bsky.social', CONFIG_FILE)

# print progress dots when loading multiple pages
bsky.default_progress = '.'

# load previously saved posts; we will only fetch posts newer than the last saved before
posts = File.exist?(POSTS_FILE) ? JSON.parse(File.read(POSTS_FILE)) : []
latest_date = posts[0] && posts[0]['indexedAt']

# fetch all posts from my timeline (without replies) until the target timestamp
results = bsky.fetch_all('app.bsky.feed.getAuthorFeed',
  { actor: bsky.user.did, filter: 'posts_no_replies', limit: 100 },
  field: 'feed',
  break_when: latest_date && proc { |x| x['post']['indexedAt'] <= latest_date }
)

# trim some data to save space
new_posts = results.map { |x| x['post'] }
  .reject { |x| x['author']['did'] != bsky.user.did }   # skip reposts
  .map { |x| x.except('author') }                       # skip author profile info

posts = new_posts + posts

puts
puts "Fetched #{new_posts.length} new posts (total = #{posts.length})"

# save all new and old posts back to the file
File.write(POSTS_FILE, JSON.pretty_generate(posts))
