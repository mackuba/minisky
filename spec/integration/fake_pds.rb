# frozen_string_literal: true

require 'json'
require 'uri'
require 'webrick'

class FakePDS
  HOST = '127.0.0.1'

  Request = Struct.new(:method, :path, :query, :headers, :body) do
    def json_body
      JSON.parse(body)
    end
  end

  attr_reader :url

  def initialize
    @routes = {}
    @requests = []

    @lock = Mutex.new
  end

  def run
    started = Queue.new

    server = WEBrick::HTTPServer.new(
      BindAddress: HOST,
      ServerName: HOST,
      Port: 0,
      DoNotReverseLookup: true,
      RequestTimeout: 5,
      AccessLog: [],
      Logger: WEBrick::Log.new(nil, WEBrick::Log::ERROR),
      StartCallback: -> { started << true }
    )

    @url = "http://#{HOST}:#{server[:Port]}"
    server.mount_proc('/') { |request, response| handle_request(request, response) }

    thread = Thread.new do
      server.start
    ensure
      started << false
    end

    raise 'Simulated PDS stopped during startup' unless started.pop

    yield
  ensure
    server&.shutdown
    thread&.join
  end

  def on(method, nsid, returns: {}, &handler)
    @lock.synchronize do
      status = returns[:status] || 200
      headers = returns[:headers] || {}
      body = returns[:body] || ''

      @routes[[method.to_s.upcase, "/xrpc/#{nsid}"]] = [status, headers, handler || ->(_request) { body }]
    end
  end

  def requests
    @lock.synchronize { @requests.dup }
  end


  private

  def handle_request(http_request, response)
    request_body = http_request.body.to_s
    query = URI.decode_www_form(http_request.query_string.to_s)
    request_headers = http_request.header.transform_values(&:dup)
    request = Request.new(http_request.request_method, http_request.path, query, request_headers, request_body)

    route = @lock.synchronize do
      @requests << request
      @routes[[request.method, request.path]]
    end

    if route
      status, headers, handler = route

      response.status = status
      headers.each { |name, value| response[name] = value }
      body = handler.call(request)

      if body.is_a?(Hash) || body.is_a?(Array)
        response['Content-Type'] ||= 'application/json'
        response.body = JSON.generate(body)
      else
        response['Content-Type'] ||= 'text/plain'
        response.body = body
      end
    else
      response.status = 404
      response['Content-Type'] = 'text/plain'
      response.body = "No route for #{request.method} #{request.path}"
    end
  end
end
