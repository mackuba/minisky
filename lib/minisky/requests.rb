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
      if name.to_s.end_with?('=')
        @config[name.to_s.chop] = args[0]
      else
        @config[name.to_s]
      end
    end
  end

  # Regexp for NSID identifiers, used in lexicon names for record collection and API endpoints
  NSID_REGEXP = /^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(\.[a-zA-Z]([a-zA-Z]{0,61}[a-zA-Z])?)$/

  #
  # This module contains most of the Minisky code for making HTTP requests and managing
  # authentication tokens. The module is included into the {Minisky} API client class and you'll
  # normally use it through that class, but you can also include it into your custom class if you
  # want to implement the data storage differently than using a local YAML file as {Minisky} does.
  #

  module Requests

    # A character to print before each request in {#fetch_all} as a progress indicator.
    # Can also be passed explicitly instead or overridden using the `progress:` parameter.
    # Default is `'.'` when running inside IRB, and `nil` otherwise.
    #
    # @return [String, nil]
    #
    attr_accessor :default_progress

    attr_writer :send_auth_headers
    attr_writer :auto_manage_tokens

    # Tells whether to set authentication headers automatically (default: true).
    #
    # If false, you will need to pass `auth: 'sometoken'` explicitly to requests that
    # require authentication.
    #
    # @return [Boolean] whether to set authentication headers in requests
    #
    def send_auth_headers
      instance_variable_defined?('@send_auth_headers') ? @send_auth_headers : true
    end

    # Tells whether the library should manage the access & refresh tokens automatically
    # for you (default: true).
    #
    # If true, {#check_access} is called before each request to make sure that there is a
    # fresh access token available; if false, you will need to call {#log_in} and
    # {#perform_token_refresh} manually when needed.
    #
    # @return [Boolean] whether to automatically manage access tokens
    #
    def auto_manage_tokens
      instance_variable_defined?('@auto_manage_tokens') ? @auto_manage_tokens : true
    end

    alias progress default_progress
    alias progress= default_progress=

    def base_url
      if host.include?('://')
        host.chomp('/') + '/xrpc'
      else
        "https://#{host}/xrpc"
      end
    end

    def user
      @user ||= User.new(config)
    end

    # Sends a GET request to the service's API.
    #
    # @param method [String, URI] an XRPC endpoint name or a full URL
    # @param params [Hash, nil] query parameters
    #
    # @param auth [Boolean, String]
    #    boolean value which tells whether to send an auth header with the access token or not,
    #    or an explicit bearer token to use
    # @param headers [Hash, nil]
    #    additional headers to include
    #
    # @return [Hash, String] parsed JSON hash for JSON responses, or raw response body otherwise
    #
    # @raise [ArgumentError] if method name is invalid
    # @raise [BadResponse] if the HTTP response has an error status code
    # @raise [AuthError]
    #   - if logging in is required, but login or password isn't provided
    #   - if token refresh is needed, but refresh token is missing
    #   - if a token has invalid format
    #   - if required access token is missing, and {#auto_manage_tokens} is disabled
    #
    # @example Unauthenticated call
    #   sky = Minisky.new('public.api.bsky.app', nil)
    #   profile = sky.get_request('app.bsky.actor.getProfile', { actor: 'ec.europa.eu' })
    #
    # @example Authenticated call
    #   sky = Minisky.new('blacksky.app', 'config.yml')
    #   feed = sky.get_request('app.bsky.feed.getTimeline', { limit: 100 })

    def get_request(method, params = nil, auth: default_auth_mode, headers: nil)
      check_access if auto_manage_tokens && auth == true

      headers = authentication_header(auth).merge(headers || {})
      url = build_request_uri(method)

      if params && !params.empty?
        url.query = URI.encode_www_form(params)
      end

      request = Net::HTTP::Get.new(url, headers)

      response = make_request(request)
      handle_response(response)
    end

    # Sends a POST request to the service's API.
    #
    # @param method [String, URI] an XRPC endpoint name or a full URL
    # @param data [Hash, String, nil] JSON or string data to send
    #
    # @param auth [Boolean, String]
    #    boolean value which tells whether to send an auth header with the access token or not,
    #    or an explicit bearer token to use
    # @param headers [Hash, nil]
    #    additional headers to include
    # @param params [Hash, nil]
    #    query parameters to append to the URL
    #
    # @return [Hash, String] parsed JSON hash for JSON responses, or raw response body otherwise
    #
    # @raise [ArgumentError] if method name is invalid
    # @raise [BadResponse] if the HTTP response has an error status code
    # @raise [AuthError]
    #   - if logging in is required, but login or password isn't provided
    #   - if token refresh is needed, but refresh token is missing
    #   - if a token has invalid format
    #   - if required access token is missing, and {#auto_manage_tokens} is disabled
    #
    # @example Making a Bluesky post
    #   sky = Minisky.new('lab.martianbase.net', 'config.yml')
    #
    #   sky.post_request('com.atproto.repo.createRecord', {
    #     repo: sky.user.did,
    #     collection: 'app.bsky.feed.post',
    #     record: {
    #       text: "Hello Bluesky!",
    #       createdAt: Time.now.iso8601,
    #       langs: ['en']
    #     }
    #   })

    def post_request(method, data = nil, auth: default_auth_mode, headers: nil, params: nil)
      check_access if auto_manage_tokens && auth == true

      headers = authentication_header(auth).merge(headers || {})

      if data.is_a?(String) || data.nil?
        body = data.to_s
      else
        body = data.to_json
        headers["Content-Type"] = "application/json" unless headers.keys.map(&:downcase).include?('content-type')
      end

      url = build_request_uri(method)

      if params && !params.empty?
        url.query = URI.encode_www_form(params)
      end

      response = Net::HTTP.post(url, body, headers)
      handle_response(response)
    end

    # Fetches and merges paginated responses from a service's endpoint in a loop, updating the
    # cursor after each page, until the cursor is nil or a break condition is met. The data is
    # extracted from a designated field of the response (`field`) and added to a single array,
    # which is returned at the end.
    #
    # A condition for when the fetching should stop can be passed as a block in `break_when`, or
    # alternatively, a max number of pages can be passed to `max_pages` (or both together). If
    # neither is set, the fetching continues until the server returns an empty cursor.
    #
    # When experimenting in the Ruby console, you can pass `nil` as `field` (or skip the parameter)
    # to make a single request and raise an exception, which will tell you what fields are available.
    #
    # @param method [String, URI] an XRPC endpoint name or a full URL
    # @param params [Hash, nil] query parameters
    #
    # @param auth [Boolean, String]
    #    boolean value which tells whether to send an auth header with the access token or not,
    #    or an explicit bearer token to use
    # @param field [String, nil]
    #    name of the field in the responses which contains the data array
    # @param break_when [Proc, nil]
    #    if passed, the fetching will stop when the block returns true for any of the
    #    returned records, and records matching the condition will be deleted from the last page
    # @param max_pages [Integer, nil]
    #    maximum number of pages to fetch
    # @param headers [Hash, nil]
    #    additional headers to include
    # @param progress [String, nil]
    #    a character to print before each request as a progress indicator
    #
    # @return [Array] records or objects collected from all pages
    #
    # @raise [ArgumentError] if method name is invalid
    # @raise [FieldNotSetError] if field parameter wasn't set (the message tells you what fields were in the response)
    # @raise [BadResponse] if the HTTP response has an error status code
    # @raise [AuthError]
    #     - if logging in is required, but login or password isn't provided
    #     - if token refresh is needed, but refresh token is missing
    #     - if a token has invalid format
    #     - if required access token is missing, and {#auto_manage_tokens} is disabled
    #
    # @example Fetching with a `break_when` block
    #   sky = Minisky.new('public.api.bsky.app', nil)
    #   time_limit = Time.now - 86400 * 30
    #
    #   sky.fetch_all('app.bsky.feed.getAuthorFeed',
    #     { actor: 'pfrazee.com', limit: 100 },
    #     field: 'feed',
    #     progress: '|',
    #     break_when: ->(x) { Time.at(x['post']['record']['createdAt']) < time_limit }
    #   )
    #
    # @example Fetching with `max_pages`
    #   sky = Minisky.new('tngl.sh', 'config.yml')
    #   sky.fetch_all('app.bsky.feed.getTimeline', { limit: 100 }, field: 'feed', max_pages: 10)
    #
    # @example Making a request in the console with empty `field`
    #   sky = Minisky.new('public.api.bsky.app', nil)
    #   # => #<Minisky:0x0000000120f5f6b0 @host="public.api.bsky.app", ...>
    #
    #   sky.fetch_all('app.bsky.graph.getFollowers', { actor: 'sdk.blue' })
    #   # ./lib/minisky/requests.rb:270:in 'block in Minisky::Requests#fetch_all':
    #   #   Field parameter not provided; available fields: ["followers"] (Minisky::FieldNotSetError)
    #
    #   sky.fetch_all('app.bsky.graph.getFollowers', { actor: 'sdk.blue' }, field: 'followers')
    #   # => .....

    def fetch_all(method, params = nil, auth: default_auth_mode,
                  field: nil, break_when: nil, max_pages: nil, headers: nil, progress: @default_progress)
      data = []
      params = {} if params.nil?
      pages = 0

      loop do
        print(progress) if progress

        response = get_request(method, params, auth: auth, headers: headers)

        if field.nil?
          raise FieldNotSetError, response.keys.select { |f| response[f].is_a?(Array) }
        end

        records = response[field]
        cursor = response['cursor']

        data.concat(records)
        params[:cursor] = cursor
        pages += 1

        break if !cursor || pages == max_pages
        break if break_when && records.any? { |x| break_when.call(x) }
      end

      data.delete_if { |x| break_when.call(x) } if break_when
      data
    end

    # Ensures that the user has a fresh access token, by checking the access token's expiry date
    # and performing a refresh if needed, or by logging in with a password if no tokens are present.
    #
    # If {#auto_manage_tokens} is enabled (the default setting), this method is automatically called
    # before {#get_request}, {#post_request} and {#fetch_all}, so you generally don't need to call it
    # yourself.
    #
    # @return [Symbol]
    #   - `:logged_in` if a login using a password was performed
    #   - `:refreshed` if the access token was expired and was refreshed
    #   - `:ok` if no refresh was needed
    #
    # @raise [BadResponse] if login or refresh returns an error status code
    # @raise [AuthError]
    #   - if logging in is required, but login or password isn't provided
    #   - if token refresh is needed, but refresh token is missing
    #   - if a token has invalid format

    def check_access
      if !user.logged_in?
        log_in
        :logged_in
      elsif access_token_expired?
        perform_token_refresh
        :refreshed
      else
        :ok
      end
    end

    # Logs in the user using an ID and password stored in the config by calling the
    # `createSession` endpoint, and stores the received access & refresh tokens.
    #
    # This is generally handled automatically by {#check_access}. Calling this method
    # repeatedly many times in a short period of time may use up your rate limit for this
    # endpoint (which is lower than for others) and make it inaccessible to you for some
    # time.
    #
    # @return [Hash] the response JSON with access tokens
    #
    # @raise [AuthError] if login or password are missing
    # @raise [BadResponse] if the server responds with an error status code

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

    # Refreshes the access token using the stored refresh token. If successful, this
    # invalidates *both* old tokens and replaces them with new ones from the response.
    #
    # If {#auto_manage_tokens} is enabled (the default setting), this method is automatically called
    # before any requests through {#check_access}, so you generally don't need to call it yourself.
    #
    # @return [Hash] the response JSON with access tokens
    #
    # @raise [AuthError] if the refresh token is missing
    # @raise [BadResponse] if the server responds with an error status code

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

    def access_token_expired?
      token_expiration_date(user.access_token) < Time.now + 60
    end

    #
    # Clear stored access and refresh tokens, effectively logging out the user.
    #

    def reset_tokens
      user.access_token = nil
      user.refresh_token = nil
      save_config
      nil
    end

    if RUBY_VERSION.to_i == 2
      require_relative 'compat'
      prepend Ruby2Compat
    end


    private

    def make_request(request)
      # this long form is needed because #get_response only supports a headers param in Ruby 3.x
      response = Net::HTTP.start(request.uri.hostname, request.uri.port, use_ssl: (request.uri.scheme == 'https')) do |http|
        http.request(request)
      end
    end

    def build_request_uri(method)
      if method.is_a?(URI)
        method
      elsif method.include?('://')
        URI(method)
      elsif method =~ NSID_REGEXP
        URI("#{base_url}/#{method}")
      else
        raise ArgumentError, "Invalid method name #{method.inspect} (should be an NSID, URL or an URI object)"
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

    def handle_response(response)
      status = response.code.to_i
      message = response.message
      response_body = (response.content_type == 'application/json') ? JSON.parse(response.body) : response.body

      case response
      when Net::HTTPSuccess
        response_body
      when Net::HTTPRedirection
        raise UnexpectedRedirect.new(status, message, response['location'])
      else
        error_class = if response_body.is_a?(Hash) && response_body['error'] == 'ExpiredToken'
          ExpiredTokenError
        elsif response.is_a?(Net::HTTPClientError)
          ClientErrorResponse
        elsif response.is_a?(Net::HTTPServerError)
          ServerErrorResponse
        else
          BadResponse
        end

        raise error_class.new(status, message, response_body)
      end
    end
  end

  include Requests
end
