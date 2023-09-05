require_relative 'minisky'
require_relative 'errors'

require 'json'
require 'net/http'
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
    attr_writer :send_auth_headers

    def send_auth_headers
      instance_variable_defined?('@send_auth_headers') ? @send_auth_headers : true
    end

    def base_url
      @base_url ||= "https://#{host}/xrpc"
    end

    def user
      @user ||= User.new(config)
    end

    def get_request(method, params = nil, auth: default_auth_mode)
      headers = authentication_header(auth)
      url = URI("#{base_url}/#{method}")

      if params && !params.empty?
        url.query = URI.encode_www_form(params)
      end

      response = Net::HTTP.get_response(url, headers)
      handle_response(response)
    end

    def post_request(method, params = nil, auth: default_auth_mode)
      headers = authentication_header(auth).merge({ "Content-Type" => "application/json" })
      body = params ? params.to_json : ''

      response = Net::HTTP.post(URI("#{base_url}/#{method}"), body, headers)
      handle_response(response)
    end

    def fetch_all(method, params = nil, field:,
                  auth: default_auth_mode, break_when: nil, max_pages: nil, progress: @default_progress)
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

    def default_auth_mode
      !!send_auth_headers
    end

    def authentication_header(auth)
      if auth.is_a?(String)
        { 'Authorization' => "Bearer #{auth}" }
      elsif auth
        { 'Authorization' => "Bearer #{user.access_token}" }
      else
        {}
      end
    end

    def handle_response(response)
      status = response.code.to_i
      message = response.message

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPRedirection
        raise UnexpectedRedirect.new(status, response['location'])
      else
        data = (response.content_type == 'application/json') ? JSON.parse(response.body) : response.body

        error_class = if data.is_a?(Hash) && data['error'] == 'ExpiredToken'
          ExpiredTokenError
        elsif response.is_a?(Net::HTTPClientError)
          ClientErrorResponse
        elsif response.is_a?(Net::HTTPServerError)
          ServerErrorResponse
        else
          BadResponse
        end

        raise error_class.new(status, message, data)
      end
    end
  end

  include Requests
end
