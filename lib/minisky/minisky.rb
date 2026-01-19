require 'yaml'

# Main client for interacting with AT Protocol servers.
class Minisky
  # @return [String] the host name or base URL for the server
  # @return [Hash] the loaded configuration data
  attr_reader :host, :config

  # Create a new client instance.
  #
  # @param host [String] the host name or base URL for the server
  # @param config_file [String, nil] path to the YAML config file
  # @param options [Hash] optional attribute overrides to apply
  # @raise [AuthError] if the config file is missing required credentials
  def initialize(host, config_file, options = {})
    @host = host
    @config_file = config_file

    if @config_file
      @config = YAML.load(File.read(@config_file))

      if user.id.nil? || user.pass.nil?
        raise AuthError, "Missing user id or password in the config file #{@config_file}"
      end
    else
      @config = {}
      @send_auth_headers = false
      @auto_manage_tokens = false
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

  # Check whether the current process looks like an interactive REPL.
  #
  # @return [Boolean] true when running inside IRB or Pry
  def active_repl?
    return true if defined?(IRB) && IRB.respond_to?(:CurrentContext) && IRB.CurrentContext
    return true if defined?(Pry) && Pry.respond_to?(:cli) && Pry.cli
    false
  end

  # Persist the current configuration to disk.
  #
  # @return [void]
  def save_config
    File.write(@config_file, YAML.dump(@config)) if @config_file
  end
end

require_relative 'requests'
