require 'yaml'
require_relative 'shared/ex_authed_user'
require_relative 'shared/ex_unauthed_user'

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
      expect { subject }.to raise_error(Minisky::AuthError, /Missing user id/)
    end
  end

  context 'if id field is not included' do
    before do
      File.write('myconfig.yml', YAML.dump(data.slice('pass', 'access_token', 'refresh_token')))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError, /Missing user id/)
    end
  end

  context 'if pass field is nil' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('pass' => nil)))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError, /Missing password/)
    end
  end

  context 'if pass field is not included' do
    before do
      File.write('myconfig.yml', YAML.dump(data.slice('id', 'access_token', 'refresh_token')))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError, /Missing password/)
    end
  end

  context 'if the user ID is an email' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('id' => 'jerry@blueskyweb.xyz')))
    end

    it 'should raise AuthError' do
      expect { subject }.to raise_error(Minisky::AuthError, /no longer supported in Minisky/)
    end
  end

  context 'if the user ID is not a handle or DID' do
    it 'should raise AuthError' do
      ['https://foo.bar', 'something', 'a...b'].each do |value|
        File.write('myconfig.yml', YAML.dump(data.merge('id' => value)))

        expect { subject }.to raise_error(Minisky::AuthError, /Invalid user identifier/)
      end
    end
  end

  context 'if the user ID is a handle' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('id' => 'blueskyweb.xyz')))
    end

    it 'should not raise an error' do
      expect { subject }.to_not raise_error
    end
  end

  context 'if the user ID is a handle with @' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('id' => '@blueskyweb.xyz')))
    end

    it 'should not raise an error' do
      expect { subject }.to_not raise_error
    end
  end

  context 'if the user ID is a did:plc' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('id' => 'did:plc:pocibtmmmrflk6elnjt27hab')))
    end

    it 'should not raise an error' do
      expect { subject }.to_not raise_error
    end
  end

  context 'if the user ID is a did:web' do
    before do
      File.write('myconfig.yml', YAML.dump(data.merge('id' => 'did:web:blue.mackuba.eu')))
    end

    it 'should not raise an error' do
      expect { subject }.to_not raise_error
    end
  end

  context 'with a user config included' do
    before do
      File.write('myconfig.yml', YAML.dump(data))
    end

    it 'should send auth headers by default' do
      subject.send_auth_headers.should == true
    end

    it 'should manage tokens by default' do
      subject.auto_manage_tokens.should == true
    end

    it 'should set host and config properties' do
      subject.host.should == host
      subject.config.should be_a(Hash)
      subject.config.should == data
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

    it 'should set host property' do
      subject.host.should == host
    end

    it 'should set config to nil' do
      subject.config.should be_nil
    end
  end

  context 'if running inside IRB' do
    subject { Minisky.new(host, nil) }

    before do
      load File.join(__dir__, 'shared', 'fake_irb.rb')
    end

    it 'should set default_progress to "."' do
      subject.default_progress.should == '.'
    end

    after do
      Object.send(:remove_const, :IRB)
    end
  end

  context 'if running inside Pry' do
    subject { Minisky.new(host, nil) }

    before do
      load File.join(__dir__, 'shared', 'fake_pry.rb')
    end

    it 'should set default_progress to "."' do
      subject.default_progress.should == '.'
    end

    after do
      Object.send(:remove_const, :Pry)
    end
  end

  context 'if not running inside a REPL' do
    subject { Minisky.new(host, nil) }

    it 'should keep default_progress unset' do
      subject.default_progress.should be_nil
    end
  end

  it 'should let you pass additional options and set them' do
    File.write('myconfig.yml', YAML.dump(data))

    minisky = Minisky.new(host, 'myconfig.yml', auto_manage_tokens: false, progress: '*')
    minisky.auto_manage_tokens.should == false
    minisky.default_progress.should == '*'
  end

  describe '#token_expiration_date' do
    subject { Minisky.new(host, nil) }

    def token_with_payload(payload)
      ['header', payload, 'sig'].join('.')
    end

    def token_with_json(json)
      token_with_payload(Base64.strict_encode64(JSON.generate(json)))
    end

    it 'should return nil for tokens with invalid encoding' do
      token = token_with_payload("bad\xC3").force_encoding('UTF-8')

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil for tokens with invalid Base64' do
      token = token_with_payload("^&@#$%@#$%@#z")

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when the token does not have three parts' do
      subject.token_expiration_date('token').should be_nil
      subject.token_expiration_date('one.two').should be_nil
      subject.token_expiration_date('1.2.3.4').should be_nil

      token = make_token(Time.now + 3600)
      subject.token_expiration_date(token + '.qwe').should be_nil
    end

    it 'should return nil when the payload is not valid JSON' do
      token = token_with_payload(Base64.strict_encode64('nope'))

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when the payload is nil' do
      token = token_with_json(nil)

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when the payload is not a hash' do
      payloads = [
        ['exp', 1794252561],
        1794252561,
        true
      ]

      payloads.each do |payload|
        token = token_with_json(payload)

        subject.token_expiration_date(token).should be_nil
      end
    end

    it 'should return nil when exp field is missing' do
      token = token_with_json('aud' => 'aaaa')

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when exp field is not a number' do
      token = token_with_json('exp' => 'soon')

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when exp field is not a positive number' do
      token = token_with_json('exp' => 0)

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when expiration year is before 2023' do
      token = make_token(Time.utc(2022, 12, 24, 19, 00, 00))

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return nil when expiration year is after 2100' do
      token = make_token(Time.utc(2101, 5, 5, 0, 0, 0))

      subject.token_expiration_date(token).should be_nil
    end

    it 'should return the expiration time for a valid token' do
      time = Time.at(Time.now.to_i + 7200)
      token = make_token(time)

      subject.token_expiration_date(token).should == time
    end

    it 'should correctly parse url-safe Base64' do
      json = '{"exp":1893456000,"aud":"???"}'
      encoded = Base64.urlsafe_encode64(json, padding: false)
      encoded.should == "eyJleHAiOjE4OTM0NTYwMDAsImF1ZCI6Ij8_PyJ9"

      token = token_with_payload(encoded)
      date = subject.token_expiration_date(token)
      date.should_not be_nil
      date.to_i.should == 1893456000

      json = '{"exp":1893456000,"aud":">>>"}'
      encoded = Base64.urlsafe_encode64(json, padding: false)
      encoded.should == "eyJleHAiOjE4OTM0NTYwMDAsImF1ZCI6Ij4-PiJ9"

      token = token_with_payload(encoded)
      date = subject.token_expiration_date(token)
      date.should_not be_nil
      date.to_i.should == 1893456000
    end
  end

  describe '#access_token_expired?' do
    let(:config) { data }

    before do
      File.write('myconfig.yml', YAML.dump(config))
    end

    context 'when there is no user config' do
      subject { Minisky.new(host, nil) }

      it 'should raise AuthError' do
        expect { subject.access_token_expired? }.to raise_error(Minisky::AuthError)
      end
    end

    context 'when access token is missing' do
      let(:config) { data.merge('access_token' => nil) }

      it 'should raise AuthError' do
        expect { subject.access_token_expired? }.to raise_error(Minisky::AuthError)
      end
    end

    context 'when token expiration cannot be decoded' do
      let(:config) { data.merge('access_token' => 'blob') }

      it 'should raise AuthError' do
        expect { subject.access_token_expired? }.to raise_error(Minisky::AuthError)
      end
    end

    context 'when token expiration date is in the past' do
      let(:config) { data.merge('access_token' => make_token(Time.now - 30)) }

      it 'should return true' do
        subject.access_token_expired?.should == true
      end
    end

    context 'when token expiration date is in less than 60 seconds' do
      let(:config) { data.merge('access_token' => make_token(Time.now + 50)) }

      it 'should return true' do
        subject.access_token_expired?.should == true
      end
    end

    context 'when token expiration date is in more than 60 seconds' do
      let(:config) { data.merge('access_token' => make_token(Time.now + 180)) }

      it 'should return false' do
        subject.access_token_expired?.should == false
      end
    end
  end
end

describe 'in Minisky instance' do
  include FakeFS::SpecHelpers

  subject { Minisky.new(host, 'myconfig.yml') }

  let(:reloaded_config) { YAML.load(File.read('myconfig.yml')) }

  context 'with a user config,' do
    before do
      File.write('myconfig.yml', YAML.dump(data))
    end

    include_examples "authenticated user", 'bsky.test'
  end

  context 'without a config,' do
    subject { Minisky.new(host, nil) }

    include_examples "unauthenticated user"
  end
end
