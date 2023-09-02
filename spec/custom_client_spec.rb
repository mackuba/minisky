require 'json'

class CustomJSONClient
  CONFIG_FILE = 'test.json'

  include Minisky::Requests

  def initialize
    @config = JSON.parse(File.read(CONFIG_FILE))
  end

  def host
    'at.x.com'
  end

  def save_config
    File.write(CONFIG_FILE, JSON.generate(@config))
  end
end

describe "custom client" do
  include FakeFS::SpecHelpers

  before do
    File.write('test.json', %({
      "id": "john.foo",
      "pass": "hunter2",
      "access_token": "aatoken",
      "refresh_token": "rrtoken"
    }))
  end

  subject { CustomJSONClient.new }

  let(:reloaded_config) { JSON.parse(File.read('test.json')) }

  include_examples "Requests", 'at.x.com'
end
