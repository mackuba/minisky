require 'json'
require 'net/http'
require 'open-uri'
require 'yaml'

class Minisky
  CONFIG_FILE = 'bluesky.yml'

  def initialize
    @config = YAML.load(File.read(CONFIG_FILE))
    @base_url = "https://#{@config['host']}/xrpc"
  end

  def my_id
    @config['ident']
  end

  def my_did
    @config['did']
  end

  def access_token
    @config['access_token']
  end

  def refresh_token
    @config['refresh_token']
  end

  def save_config
    File.write(CONFIG_FILE, YAML.dump(@config))
  end

  def log_in
    json = post_request('com.atproto.server.createSession', {
      identifier: @config['ident'],
      password: @config['pass']
    })

    @config['did'] = json['did']
    @config['access_token'] = json['accessJwt']
    @config['refresh_token'] = json['refreshJwt']
    save_config
  end

  def perform_token_refresh
    json = post_request('com.atproto.server.refreshSession', nil, refresh_token)
    @config['access_token'] = json['accessJwt']
    @config['refresh_token'] = json['refreshJwt']
    save_config
  end

  def fetch_all(method, params, auth = nil, field:, break_when: ->(x) { false }, progress: true)
    data = []

    loop do
      print '.' if progress

      response = get_request(method, params, auth)
      records = response[field]
      cursor = response['cursor']

      data.concat(records)
      params[:cursor] = cursor

      break if cursor.nil? || records.empty? || records.any? { |x| break_when.call(x) }
    end

    data.reject { |x| break_when.call(x) }
  end

  def get_request(method, params = nil, auth = nil)
    headers = {}
    headers['Authorization'] = "Bearer #{auth}" if auth

    url = "#{@base_url}/#{method}"

    if params && !params.empty?
      url += "?" + params.map { |k, v|
        if v.is_a?(Array)
          v.map { |x| "#{k}=#{x}" }.join('&')
        else
          "#{k}=#{v}"
        end
      }.join('&')
    end

    JSON.parse(URI.open(url, headers).read)
  end

  def post_request(method, params, auth = nil)
    headers = { "Content-Type" => "application/json" }
    headers['Authorization'] = "Bearer #{auth}" if auth

    body = params ? params.to_json : ''

    response = Net::HTTP.post(URI("#{@base_url}/#{method}"), body, headers)
    raise "Invalid response: #{response.code} #{response.body}" if response.code.to_i / 100 != 2

    JSON.parse(response.body)
  end
end
