#!/usr/bin/env ruby

# Example: fetch the list of accounts followed by a given user and check which of them have been deleted / deactivated.

# load minisky from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'didkit'
require 'minisky'

handle = ARGV[0].to_s.gsub(/^@/, '')
if handle.empty?
  puts "Usage: #{$PROGRAM_NAME} <handle>"
  exit 1
end

pds_host = DID.resolve_handle(handle).get_document.pds_endpoint
pds = Minisky.new(pds_host, nil, progress: '.')

print "Fetching all follows of @#{handle} from #{pds_host}: "

follows = pds.fetch_all('com.atproto.repo.listRecords',
  { repo: handle, collection: 'app.bsky.graph.follow', limit: 100 }, field: 'records')

puts
puts "Found #{follows.length} follows"

appview = Minisky.new('api.bsky.app', nil)

profiles = []
i = 0

puts
print "Fetching profiles of all followed accounts: "

# getProfiles lets us load multiple profiles in one request, but only up to 25 in one batch

while i < follows.length
  batch = follows[i...i+25]
  dids = batch.map { |x| x['value']['subject'] }
  print '.'
  result = appview.get_request('app.bsky.actor.getProfiles', { actors: dids })
  profiles += result['profiles']
  i += 25
end

# these are DIDs that are on the follows list, but aren't being returned from getProfiles
missing = follows.map { |x| x['value']['subject'] } - profiles.map { |x| x['did'] }

puts
puts "#{missing.length} followed accounts are missing:"
puts

missing.each do |did|
  begin
    doc = DID.new(did).get_document
  rescue OpenURI::HTTPError
    puts "#{did} (?) => DID not found"
    next
  end

  # check account status on their assigned PDS
  pds = Minisky.new(doc.pds_endpoint, nil)
  status = pds.get_request('com.atproto.sync.getRepoStatus', { did: did }).slice('status', 'active') rescue 'deleted'

  puts "#{did} (@#{doc.handles.first}) => #{status}"
end
