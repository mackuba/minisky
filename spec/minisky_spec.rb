require 'yaml'
require_relative 'shared/ex_requests'
require_relative 'shared/ex_unauthed'

data = {
  'id' => 'john.foo',
  'pass' => 'hunter2',
  'access_token' => 'aatoken',
  'refresh_token' => 'rrtoken'
}.freeze

host = 'bsky.test'

describe Minisky do
  include FakeFS::SpecHelpers

  subject { Minisky.new(host, 'myconfig.yml') }

  it 'should have a version number' do
    Minisky::VERSION.should_not be_nil
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

  context 'with correct config' do
    before do
      File.write('myconfig.yml', YAML.dump(data))
    end

    it 'should send auth headers by default' do
      subject.send_auth_headers.should == true
    end

    it 'should manage tokens by default' do
      subject.auto_manage_tokens.should == true
    end
  end

  context 'without a config' do
    subject { Minisky.new(host, nil) }

    it 'should not send auth headers' do
      subject.send_auth_headers.should == false
    end

    it 'should not manage tokens' do
      subject.auto_manage_tokens.should == false
    end
  end
end

describe 'in Minisky instance' do
  include FakeFS::SpecHelpers

  subject { Minisky.new(host, 'myconfig.yml') }

  let(:reloaded_config) { YAML.load(File.read('myconfig.yml')) }

  context 'with correct config,' do
    before do
      File.write('myconfig.yml', YAML.dump(data))
    end

    include_examples "authenticated requests", 'bsky.test'
  end

  context 'without a config' do
    subject { Minisky.new(host, nil) }

    include_examples "unauthenticated user"
  end
end
