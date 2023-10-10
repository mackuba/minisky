require_relative 'minisky'
require_relative 'errors'

require 'base64'
require 'json'
require 'net/http'
require 'time'
require 'uri'

class Minisky
  class User
    def initialize(config)
      @config = config
    end

    def logged_in?
      !!(access_token && refresh_token)
    end

    def method_missing(name, *args)
      if name.end_with?('=')
        @config[name.to_s.chop] = args[0]
      else
        @config[name.to_s]
      end
    end
  end

  module Requests
    attr_accessor :default_progress
    attr_writer :send_auth_headers
    attr_writer :auto_manage_tokens

    def send_auth_headers
      instance_variable_defined?('@send_auth_headers') ? @send_auth_headers : true
    end

    def auto_manage_tokens
      instance_variable_defined?('@auto_manage_tokens') ? @auto_manage_tokens : true
    end

    def base_url
      @base_url ||= "https://#{host}/xrpc"
    end

    def user
      @user ||= User.new(config)
    end

    def get_request(method, params = nil, auth: default_auth_mode)
      check_access if auto_manage_tokens && auth == true

      headers = authentication_header(auth)
      url = URI("#{base_url}/#{method}")

      if params && !params.empty?
        url.query = URI.encode_www_form(params)
      end

      request = Net::HTTP::Get.new(url, headers)

      response = make_request(request)
      handle_response(response)
    end

    def post_request(method, params = nil, auth: default_auth_mode)
      check_access if auto_manage_tokens && auth == true

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
      elsif token_expiration_date(user.access_token) < Time.now + 60
        perform_token_refresh
      end
    end

    def log_in
      if user.id.nil? || user.pass.nil?
        raise AuthError, "To log in, please provide a user id and password"
      end

      data = {
        identifier: user.id,
        password: user.pass
      }

      json = post_request('com.atproto.server.createSession', data, auth: false)

      user.did = json['did']
      user.access_token = json['accessJwt']
      user.refresh_token = json['refreshJwt']

      save_config
      json
    end

    def perform_token_refresh
      if user.refresh_token.nil?
        raise AuthError, "Can't refresh access token - refresh token is missing"
      end

      json = post_request('com.atproto.server.refreshSession', auth: user.refresh_token)

      user.access_token = json['accessJwt']
      user.refresh_token = json['refreshJwt']

      save_config
      json
    end

    def reset_tokens
      user.access_token = nil
      user.refresh_token = nil
      save_config
      nil
    end

    if RUBY_VERSION.to_i == 2
      alias_method :do_get_request, :get_request
      alias_method :do_post_request, :post_request
      private :do_get_request, :do_post_request

      def get_request(method, params = nil, auth: default_auth_mode, **kwargs)
        do_get_request(method, params || kwargs, auth: auth)
      end

      def post_request(method, params = nil, auth: default_auth_mode, **kwargs)
        do_post_request(method, params || kwargs, auth: auth)
      end
    end


    private

    def make_request(request)
      # this long form is needed because #get_response only supports a headers param in Ruby 3.x
      response = Net::HTTP.start(request.uri.hostname, request.uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def default_auth_mode
      !!send_auth_headers
    end

    def authentication_header(auth)
      if auth.is_a?(String)
        { 'Authorization' => "Bearer #{auth}" }
      elsif auth
        if user.access_token
          { 'Authorization' => "Bearer #{user.access_token}" }
        else
          raise AuthError, "Can't send auth headers, access token is missing"
        end
      else
        {}
      end
    end

    def token_expiration_date(token)
      parts = token.split('.')
      raise AuthError, "Invalid access token format" unless parts.length == 3

      begin
        payload = JSON.parse(Base64.decode64(parts[1]))
      rescue JSON::ParserError
        raise AuthError, "Couldn't decode payload from access token"
      end

      exp = payload['exp']
      raise AuthError, "Invalid token expiry data" unless exp.is_a?(Numeric) && exp > 0

      Time.at(exp)
    end

    def handle_response(response)
      status = response.code.to_i
      message = response.message

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPRedirection
        raise UnexpectedRedirect.new(status, message, response['location'])
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
