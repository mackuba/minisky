require_relative 'minisky'

require 'json'
require 'net/http'
require 'open-uri'

class Minisky
  module Requests
    def base_url
      @base_url ||= "https://#{host}/xrpc"
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

    def get_request(method, params = nil, auth: true)
      headers = authentication_header(auth)
      url = "#{base_url}/#{method}"

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

    def post_request(method, params, auth: true)
      headers = authentication_header(auth).merge({ "Content-Type" => "application/json" })
      body = params ? params.to_json : ''

      response = Net::HTTP.post(URI("#{base_url}/#{method}"), body, headers)
      raise "Invalid response: #{response.code} #{response.body}" if response.code.to_i / 100 != 2

      JSON.parse(response.body)
    end

    def fetch_all(method, params, field:, auth: true, break_when: ->(x) { false }, progress: true)
      data = []
      params = {} if params.nil?

      loop do
        print '.' if progress

        response = get_request(method, params, auth: auth)
        records = response[field]
        cursor = response['cursor']

        data.concat(records)
        params[:cursor] = cursor

        break if cursor.nil? || records.empty? || records.any? { |x| break_when.call(x) }
      end

      data.reject { |x| break_when.call(x) }
    end

    def check_access
      if !access_token || !refresh_token || !my_did
        log_in
      else
        begin
          get_request('com.atproto.server.getSession')
        rescue OpenURI::HTTPError
          perform_token_refresh
        end
      end
    end

    def log_in
      json = post_request('com.atproto.server.createSession', {
        identifier: @config['ident'],
        password: @config['pass']
      }, auth: false)

      @config['did'] = json['did']
      @config['access_token'] = json['accessJwt']
      @config['refresh_token'] = json['refreshJwt']
      save_config
    end

    def perform_token_refresh
      json = post_request('com.atproto.server.refreshSession', nil, auth: refresh_token)
      @config['access_token'] = json['accessJwt']
      @config['refresh_token'] = json['refreshJwt']
      save_config
    end

    private

    def authentication_header(auth)
      if auth.is_a?(String)
        { 'Authorization' => "Bearer #{auth}" }
      elsif auth
        { 'Authorization' => "Bearer #{access_token}" }
      else
        {}
      end
    end
  end

  include Requests
end
