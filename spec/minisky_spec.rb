require 'yaml'

describe Minisky do
  include FakeFS::SpecHelpers

  let(:host) { 'bsky.test' }

  subject { Minisky.new(host, 'myconfig.yml') }

  let(:reloaded_config) { YAML.load(File.read('myconfig.yml')) }

  let(:data) {{
    'id' => 'john.foo',
    'pass' => 'hunter2',
    'access_token' => 'aatoken',
    'refresh_token' => 'rrtoken'
  }}

  it 'should have a version number' do
    Minisky::VERSION.should_not be_nil
  end

  context 'with correct config' do
    before do
      File.write('myconfig.yml', YAML.dump(data))
    end

    include_examples "Requests", 'bsky.test'
  end

  context 'if id field is nil' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('id' => nil)))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError)
    end
  end

  context 'if id field is not included' do
    before do
      File.write('myconfig.yml', YAML.dump(data.slice('pass', 'access_token', 'refresh_token')))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError)
    end
  end

  context 'if pass field is nil' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('pass' => nil)))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError)
    end
  end

  context 'if pass field is not included' do
    before do
      File.write('myconfig.yml', YAML.dump(data.slice('id', 'access_token', 'refresh_token')))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError)
    end
  end
end
