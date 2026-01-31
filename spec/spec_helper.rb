require_relative 'spec_config'
require 'base64'
require 'json'

INVALID_METHOD_NAMES = [
  'getUsers',
  '127.0.0.1',
  '/xrpc/com.atproto.repo.getRecords',
  'app.bsky.feed.under_score'
]

def stub_fetch_all(base_url, responses)
  cursor = nil
  urls = []

  responses.each_with_index do |r, i|
    url = base_url
    body = r

    if cursor
      url += (url.include?('?') ? '&' : '?') + "cursor=#{cursor}"
    end

    if i < responses.length - 1
      cursor = rand.to_s
      body = body.merge("cursor" => cursor)
    end

    stub_request(:get, url).to_return_json(body: body)
    urls << url
  end

  @stubbed_urls = urls
end

def verify_fetch_all
  @stubbed_urls.each do |url|
    WebMock.should have_requested(:get, url).once
  end
end

def make_token(exp_time)
  header = { alg: 'HS256', typ: 'JWT' }
  payload = { exp: exp_time.to_i }
  signature = 'signature'

  [header, payload, signature].map { |part| Base64.strict_encode64(JSON.generate(part)) }.join('.')
end
