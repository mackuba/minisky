require 'yaml'

class Minisky
  CONFIG_FILE = 'bluesky.yml'

  def initialize
    @config = YAML.load(File.read(CONFIG_FILE))
  end

  def save_config
    File.write(CONFIG_FILE, YAML.dump(@config))
  end
end

require_relative 'requests'
