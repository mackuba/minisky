#!/usr/bin/env ruby

# Example: print 10 latest posts from the user's home feed.
# 
# Instead of using a config file to read & store authentication info, this example
# uses a customized client class which reads the password from the console and creates
# a throwaway access token.
#
# This approach makes sense for one-off scripts, but it shouldn't be used for things
# that need to be done repeatedly and often (the authentication-related endpoints have
# lower rate limits than others).

# load minisky from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'io/console'
require 'minisky'

class TransientClient
  include Minisky::Requests

  attr_reader :config, :host

  def initialize(host, user)
    @host = host
    @config = { 'id' => user.gsub(/^@/, '') }
  end

  def ask_for_password
    print "Enter password for @#{config['id']}: "
    @config['pass'] = STDIN.noecho(&:gets).chomp
    puts
  end

  def save_config
    # ignore
  end
end

host, handle = ARGV

unless host && handle
  puts "Usage: #{$PROGRAM_NAME} <pds_hostname> <handle>"
  exit 1
end

# create a client instance & read password
bsky = TransientClient.new(host, handle)
bsky.ask_for_password

# fetch 10 posts from the user's home feed
result = bsky.get_request('app.bsky.feed.getTimeline', { limit: 10 })

result['feed'].each do |r|
  reason = r['reason']
  reply = r['reply']
  post = r['post']

  if reason && reason['$type'] == 'app.bsky.feed.defs#reasonRepost'
    puts "[Reposted by @#{reason['by']['handle']}]"
  end

  handle = post['author']['handle']
  timestamp = Time.parse(post['record']['createdAt']).getlocal

  puts "@#{handle} • #{timestamp}"
  puts

  if reply
    puts "[in reply to @#{reply['parent']['author']['handle']}]"
    puts
  end

  puts post['record']['text']
  puts
  puts "=" * 120
  puts
end
