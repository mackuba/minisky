require 'json'
require_relative 'shared/ex_unauthed'

# Custom JSON-backed client for request specs.
class CustomJSONClient
  # @return [String] path to the test JSON config
  CONFIG_FILE = 'test.json'

  # Request helpers for the test client.
  include Minisky::Requests

  # @return [Hash] parsed configuration data
  attr_reader :config

  # @return [void]
  def initialize
    @config = JSON.parse(File.read(CONFIG_FILE))
  end

  # @return [String] test host name
  def host
    'at.x.com'
  end

  # @return [void]
  def save_config
    File.write(CONFIG_FILE, JSON.generate(@config))
  end
end

describe "in custom client" do
  include FakeFS::SpecHelpers

  let(:data) {{
    'id' => 'john.foo',
    'pass' => 'hunter2',
    'access_token' => 'aatoken',
    'refresh_token' => 'rrtoken'
  }}

  subject { CustomJSONClient.new }

  let(:reloaded_config) { JSON.parse(File.read('test.json')) }

  context 'with correct config,' do
    before do
      File.write('test.json', JSON.generate(data))
    end

    include_examples "Requests", 'at.x.com'
  end

  context 'if id field is nil,' do
    before do
      File.write('test.json', JSON.generate(data.merge('id' => nil)))
    end

    include_examples "unauthenticated user"
  end

  context 'if id field is not included' do
    before do
      File.write('test.json', JSON.generate(data.slice('pass', 'access_token', 'refresh_token')))
    end

    include_examples "unauthenticated user"
  end

  context 'if pass field is nil' do
    before do
      File.write('test.json', JSON.generate(data.merge('pass' => nil)))
    end

    include_examples "unauthenticated user"
  end

  context 'if pass field is not included' do
    before do
      File.write('test.json', JSON.generate(data.slice('id', 'access_token', 'refresh_token')))
    end

    include_examples "unauthenticated user"
  end
end
