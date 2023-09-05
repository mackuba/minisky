require_relative 'minisky'

require 'json'
require 'net/http'
require 'open-uri'
require 'uri'

class Minisky
  class User
    def initialize(config)
      @config = config
    end

    def logged_in?
      !!(access_token && refresh_token)
    end

    def method_missing(name)
      @config[name.to_s]
    end
  end

  module Requests
    attr_accessor :default_progress
    attr_writer :default_auth

    def default_auth
      instance_variable_defined?('@default_auth') ? @default_auth : true
    end

    def base_url
      @base_url ||= "https://#{host}/xrpc"
    end

    def user
      @user ||= User.new(config)
    end

    def get_request(method, params = nil, auth: default_auth)
      headers = authentication_header(auth)
      url = URI("#{base_url}/#{method}")

      if params && !params.empty?
        url.query = URI.encode_www_form(params)
      end

      JSON.parse(URI.open(url, headers).read)
    end

    def post_request(method, params = nil, auth: default_auth)
      headers = authentication_header(auth).merge({ "Content-Type" => "application/json" })
      body = params ? params.to_json : ''

      response = Net::HTTP.post(URI("#{base_url}/#{method}"), body, headers)
      raise "Invalid response: #{response.code} #{response.body}" if response.code.to_i / 100 != 2

      JSON.parse(response.body)
    end

    def fetch_all(method, params = nil, field:,
                  auth: default_auth, break_when: nil, max_pages: nil, progress: @default_progress)
      data = []
      params = {} if params.nil?
      pages = 0

      loop do
        print(progress) if progress

        response = get_request(method, params, auth: auth)
        records = response[field]
        cursor = response['cursor']

        data.concat(records)
        params[:cursor] = cursor
        pages += 1

        break if !cursor || records.empty? || pages == max_pages
        break if break_when && records.any? { |x| break_when.call(x) }
      end

      data.delete_if { |x| break_when.call(x) } if break_when
      data
    end

    def check_access
      if !user.logged_in?
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
      data = {
        identifier: user.id,
        password: user.pass
      }

      json = post_request('com.atproto.server.createSession', data, auth: false)

      config['did'] = json['did']
      config['access_token'] = json['accessJwt']
      config['refresh_token'] = json['refreshJwt']

      save_config
      json
    end

    def perform_token_refresh
      json = post_request('com.atproto.server.refreshSession', auth: user.refresh_token)

      config['access_token'] = json['accessJwt']
      config['refresh_token'] = json['refreshJwt']

      save_config
      json
    end

    def reset_tokens
      config['access_token'] = nil
      config['refresh_token'] = nil
      save_config
      nil
    end

    private

    def authentication_header(auth)
      if auth.is_a?(String)
        { 'Authorization' => "Bearer #{auth}" }
      elsif auth
        { 'Authorization' => "Bearer #{user.access_token}" }
      else
        {}
      end
    end
  end

  include Requests
end
