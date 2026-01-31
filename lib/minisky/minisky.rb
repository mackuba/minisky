require 'yaml'

#
# The default API client class for making requests to AT Protocol servers. Can be used
# with authentication – with the credentials stored in a YAML file – or without it, for
# unauthenticated requests only (by passing `nil` as the config file name).
#
# @example Authenticated client
#   # Expects a config.yml file like:
#   #
#   # id: test.example.com
#   # pass: secret7
#   #
#   # "id" can be a handle or a DID.
#
#   sky = Minisky.new('eurosky.social', 'config.yml')
#
#   feed = sky.get_request('app.bsky.feed.getTimeline', { limit: 100 })
#
# @example Unauthenticated client
#   sky = Minisky.new('public.api.bsky.app', nil, progress: '*')
#
#   follows = sky.get_request('app.bsky.graph.getFollows',
#     { actor: 'atproto.com', limit: 100 },
#     field: 'follows'
#   )
#

class Minisky

  # @return [String] the hostname (or base URL) of the server
  attr_reader :host

  # @return [Hash] loaded contents of the config file
  attr_reader :config

  # Creates a new client instance.
  #
  # @param host [String] the hostname (or base URL) of the server
  # @param config_file [String, nil] path to the YAML config file, or `nil` for unauthenticated client
  # @param options [Hash] option properties to set on the new instance (see {Minisky::Requests} properties)
  #
  # @raise [AuthError] if the config file is missing an ID or password
  #
  def initialize(host, config_file, options = {})
    @host = host
    @config_file = config_file

    if @config_file
      @config = YAML.load(File.read(@config_file))

      if user.id.nil? || user.pass.nil?
        raise AuthError, "Missing user id or password in the config file #{@config_file}"
      end
    else
      @config = nil
    end

    if active_repl?
      @default_progress = '.'
    end

    if options
      options.each do |k, v|
        self.send("#{k}=", v)
      end
    end
  end

  def save_config
    File.write(@config_file, YAML.dump(@config)) if @config_file
  end


  private

  def active_repl?
    return true if defined?(IRB) && IRB.respond_to?(:CurrentContext) && IRB.CurrentContext
    return true if defined?(Pry) && Pry.respond_to?(:cli) && Pry.cli
    false
  end
end

require_relative 'requests'
