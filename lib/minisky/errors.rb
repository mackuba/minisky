require_relative 'minisky'

class Minisky
  # Base error class for Minisky.
  class Error < StandardError
  end

  # Raised when authentication or credentials are invalid.
  class AuthError < Error
    # @param message [String]
    def initialize(message)
      super(message)
    end
  end

  # Raised when the API returns a non-success response.
  class BadResponse < Error
    # @return [Integer] HTTP status code
    # @return [Object] parsed response data
    attr_reader :status, :data

    # @param status [Integer]
    # @param status_message [String]
    # @param data [Object]
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

    # @return [String, nil] error type from response data
    def error_type
      @data['error'] if @data.is_a?(Hash)
    end

    # @return [String, nil] error message from response data
    def error_message
      @data['message'] if @data.is_a?(Hash)
    end
  end

  # Client error response (4xx).
  class ClientErrorResponse < BadResponse
  end

  # Server error response (5xx).
  class ServerErrorResponse < BadResponse
  end

  # Expired access token response.
  class ExpiredTokenError < ClientErrorResponse
  end

  # Raised when a redirect is encountered unexpectedly.
  class UnexpectedRedirect < BadResponse
    # @return [String] redirect location
    attr_reader :location

    # @param status [Integer]
    # @param status_message [String]
    # @param location [String]
    def initialize(status, status_message, location)
      super(status, status_message, { 'message' => "Unexpected redirect: #{location}" })
      @location = location
    end
  end

  # Raised when fetch_all cannot determine the response field.
  class FieldNotSetError < Error
    # @return [Array<String>]
    attr_reader :fields

    # @param fields [Array<String>]
    def initialize(fields)
      @fields = fields
      super("Field parameter not provided; available fields: #{@fields.inspect}")
    end
  end
end
