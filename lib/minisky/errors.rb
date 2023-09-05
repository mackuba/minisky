require_relative 'minisky'

class Minisky
  class Error < StandardError
  end

  class MissingTokenError < Error
    def initialize
      super("Can't send auth headers, access token is missing")
    end
  end

  class InvalidTokenError < Error
    def initialize(message)
      super(message)
    end
  end

  class BadResponse < Error
    attr_reader :status, :data

    def initialize(status, status_message, data)
      @status = status
      @data = data
      super(error_message || status_message)
    end

    def error_type
      @data['error'] if @data.is_a?(Hash)
    end

    def error_message
      @data['message'] if @data.is_a?(Hash)
    end
  end

  class ClientErrorResponse < BadResponse
  end

  class ServerErrorResponse < BadResponse
  end

  class ExpiredTokenError < ClientErrorResponse
  end

  class UnexpectedRedirect < BadResponse
    attr_reader :location

    def initialize(status, location)
      super(status, "Unexpected redirect: #{location}", nil)
      @location = location
    end
  end
end
