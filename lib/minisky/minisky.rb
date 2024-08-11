require 'yaml'

class Minisky
  attr_reader :host, :config

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

  def active_repl?
    return true if defined?(IRB) && IRB.respond_to?(:CurrentContext) && IRB.CurrentContext
    return true if defined?(Pry) && Pry.respond_to?(:cli) && Pry.cli
    false
  end

  def save_config
    File.write(@config_file, YAML.dump(@config)) if @config_file
  end
end

require_relative 'requests'
