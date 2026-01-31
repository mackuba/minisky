require 'json'
require_relative 'shared/ex_incomplete_auth'
require_relative 'shared/ex_requests'
require_relative 'shared/ex_unauthed'

class CustomJSONClient
  CONFIG_FILE = 'test.json'

  include Minisky::Requests

  attr_reader :config

  def initialize(config_file = CONFIG_FILE)
    @config = config_file && JSON.parse(File.read(config_file))
  end

  def host
    'at.x.com'
  end

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

    it 'should send auth headers by default' do
      subject.send_auth_headers.should == true
    end

    it 'should manage tokens by default' do
      subject.auto_manage_tokens.should == true
    end

    it 'should not set default progress' do
      subject.progress.should be_nil
    end

    describe '(requests)' do
      include_examples "authenticated requests", 'at.x.com'
    end
  end

  context 'with no user config,' do
    subject { CustomJSONClient.new(nil) }

    it 'should not send auth headers' do
      subject.send_auth_headers.should == false
    end

    it 'should not manage tokens' do
      subject.auto_manage_tokens.should == false
    end

    it 'should not set default progress' do
      subject.progress.should be_nil
    end

    include_examples "unauthenticated user"
  end

  context 'if id field is nil,' do
    before do
      File.write('test.json', JSON.generate(id: nil, pass: 'ok'))
    end

    include_examples "custom client with incomplete auth"
  end

  context 'if id field is not included' do
    before do
      File.write('test.json', JSON.generate(pass: 'ok'))
    end

    include_examples "custom client with incomplete auth"
  end

  context 'if pass field is nil' do
    before do
      File.write('test.json', JSON.generate(id: 'id', pass: nil))
    end

    include_examples "custom client with incomplete auth"
  end

  context 'if pass field is not included' do
    before do
      File.write('test.json', JSON.generate(id: 'id'))
    end

    include_examples "custom client with incomplete auth"
  end
end
