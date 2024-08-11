require_relative 'minisky'

class Minisky
  class Error < StandardError
  end

  class AuthError < Error
    def initialize(message)
      super(message)
    end
  end

  class BadResponse < Error
    attr_reader :status, :data

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

    def initialize(status, status_message, location)
      super(status, status_message, { 'message' => "Unexpected redirect: #{location}" })
      @location = location
    end
  end

  class FieldNotSetError < Error
    attr_reader :fields

    def initialize(fields)
      @fields = fields
      super("Field parameter not provided; available fields: #{@fields.inspect}")
    end
  end
end
