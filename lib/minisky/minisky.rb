require 'yaml'

class Minisky
  attr_reader :host, :config

  def initialize(host, config_file)
    @host = host
    @config_file = config_file
    @config = YAML.load(File.read(@config_file))

    if user.id.nil? || user.pass.nil?
      raise AuthError, "Missing user id or password in the config file #{@config_file}"
    end
  end

  def save_config
    File.write(@config_file, YAML.dump(@config))
  end
end

require_relative 'requests'
