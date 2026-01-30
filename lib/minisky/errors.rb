require_relative 'minisky'

class Minisky

  #
  # Common base error class for Minisky errors.
  #
  class Error < StandardError
  end

  #
  # Raised when a required token or credentials are missing or invalid.
  #
  class AuthError < Error
  end

  #
  # Raised when the API returns an error status code.
  #
  class BadResponse < Error

    # @return [Integer] HTTP status code
    attr_reader :status

    # @return [String, Hash] response data (JSON hash or string)
    attr_reader :data

    # @param status [Integer] HTTP status code
    # @param status_message [String] HTTP status message
    # @param data [Hash, String] response data (JSON hash or string)
    #
    def initialize(status, status_message, data)
      @status = status
      @data = data

      message = if error_message
        "#{status} #{status_message}: #{error_message}"
      else
        "#{status} #{status_message}"
      end

      super(message)
    end

    # @return [String, nil] machine-readable error code from the response data
    def error_type
      @data['error'] if @data.is_a?(Hash)
    end

    # @return [String, nil] human-readable error message from the response data
    def error_message
      @data['message'] if @data.is_a?(Hash)
    end
  end

  #
  # Raised when the API returns a client error status code (4xx).
  #
  class ClientErrorResponse < BadResponse
  end

  #
  # Raised when the API returns a server error status code (5xx).
  #
  class ServerErrorResponse < BadResponse
  end

  #
  # Raised when the API returns an error indicating that the access or request
  # token that was passed in the header is expired.
  #
  class ExpiredTokenError < ClientErrorResponse
  end

  #
  # Raised when the API returns a redirect status code (3xx). Minisky doesn't
  # currently follow any redirects.
  #
  class UnexpectedRedirect < BadResponse

    # @return [String] value of the "Location" header
    attr_reader :location

    # @param status [Integer] HTTP status code
    # @param status_message [String] HTTP status message
    # @param location [String] value of the "Location" header
    #
    def initialize(status, status_message, location)
      super(status, status_message, { 'message' => "Unexpected redirect: #{location}" })
      @location = location
    end
  end

  #
  # Raised by {Requests#fetch_all} when the `field` parameter isn't set.
  #
  # The message of the exception lists the fields available in the first fetched page.
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
  #
  class FieldNotSetError < Error

    # @return [Array<String>] list of fields in the response data
    attr_reader :fields

    # @param fields [Array<String>] list of fields in the response data
    #
    def initialize(fields)
      @fields = fields
      super("Field parameter not provided; available fields: #{@fields.inspect}")
    end
  end
end
