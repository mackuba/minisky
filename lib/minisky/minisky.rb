require 'yaml'

class Minisky
  DEFAULT_CONFIG_FILE = 'bluesky.yml'

  attr_reader :host

  def initialize(host, config_file = DEFAULT_CONFIG_FILE)
    @host = host
    @config_file = config_file
    @config = YAML.load(File.read(@config_file))
  end

  def save_config
    File.write(@config_file, YAML.dump(@config))
  end
end

require_relative 'requests'
