# frozen_string_literal: true

describe Minisky do
  include FakeFS::SpecHelpers

  let(:host) { 'bsky.test' }

  subject { Minisky.new(host) }

  before do
    File.write('bluesky.yml', %(
      ident: john.foo
      pass: hunter2
      access_token: aatoken
      refresh_token: rrtoken
    ))
  end

  def config_yaml
    YAML.load(File.read('bluesky.yml'))
  end

  it 'should have a version number' do
    Minisky::VERSION.should_not be_nil
  end

  it 'should load config from a file' do
    subject.my_id.should == 'john.foo'
    subject.access_token.should == 'aatoken'
    subject.refresh_token.should == 'rrtoken'
  end

  describe '#log_in' do
    before do
      stub_request(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
        .to_return(body: %({
          "did": "did:plc:abracadabra",
          "accessJwt": "aaaa1234",
          "refreshJwt": "rrrr1234"
        }))
    end

    it 'should make a request to com.atproto.server.createSession' do
      subject.log_in

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
        .once.with(body: %({"identifier":"john.foo","password":"hunter2"}))
    end

    it 'should not set authentication header' do
      subject.log_in

      WebMock.should_not have_requested(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
        .with(headers: { 'Authorization' => /.*/ })
    end

    it "should save user's DID" do
      subject.log_in

      config_yaml['did'].should == "did:plc:abracadabra"
    end

    it "should update the tokens in the config file" do
      subject.log_in

      config_yaml['access_token'].should == 'aaaa1234'
      config_yaml['refresh_token'].should == 'rrrr1234'
    end
  end

  describe '#perform_token_refresh' do
    before do
      stub_request(:post, "https://#{host}/xrpc/com.atproto.server.refreshSession")
        .to_return(body: %({
          "accessJwt": "aaaa1234",
          "refreshJwt": "rrrr1234"
        }))
    end

    it 'should make a request to com.atproto.server.refreshSession' do
      subject.perform_token_refresh

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.refreshSession")
        .once.with(body: '')
    end

    it 'should authenticate with the refresh token' do
      subject.perform_token_refresh

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.refreshSession")
        .once.with(headers: { 'Authorization' => 'Bearer rrtoken' })
    end

    it "should update the tokens in the config file" do
      subject.perform_token_refresh

      config_yaml['access_token'].should == 'aaaa1234'
      config_yaml['refresh_token'].should == 'rrrr1234'
    end
  end

  describe '#get_request' do
    before do
      stub_request(:get, %r(https://#{host}/xrpc/com.example.service.getStuff(\?.*)?))
        .to_return(body: '{ "result": 123 }')
    end

    it 'should make a request to the given XRPC endpoint' do
      subject.get_request('com.example.service.getStuff')

      WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
    end

    it 'should return parsed JSON' do
      result = subject.get_request('com.example.service.getStuff')

      result.should == { 'result' => 123 }
    end

    context 'with params' do
      it 'should append params to the URL' do
        subject.get_request('com.example.service.getStuff', { repo: 'whitehouse.gov', limit: 80 })

        WebMock.should have_requested(:get,
         "https://#{host}/xrpc/com.example.service.getStuff?repo=whitehouse.gov&limit=80").once
      end
    end

    context 'with an array passed as param' do
      it 'should append one copy of the param for each item' do
        subject.get_request('com.example.service.getStuff', { profiles: ['john.foo', 'spam.zip'], reposts: true })

        WebMock.should have_requested(:get,
         "https://#{host}/xrpc/com.example.service.getStuff?profiles=john.foo&profiles=spam.zip&reposts=true").once
      end
    end

    context 'with auth token' do
      it 'should pass the token in the header' do
        subject.get_request('com.example.service.getStuff', nil, 'token777')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
          .with(headers: { 'Authorization' => 'Bearer token777' })
      end
    end

    context 'without auth token' do
      it 'should not set the authorization header' do
        subject.get_request('com.example.service.getStuff')

        WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff")
          .with(headers: { 'Authorization' => /.*/ })
      end
    end
  end

  describe '#post_request' do
    let(:response) {{ body: '{ "result": "ok" }' }}

    before do
      stub_request(:post, %r(https://#{host}/xrpc/com.example.service.doStuff)).to_return(response)
    end

    it 'should make a request to the given XRPC endpoint' do
      subject.post_request('com.example.service.doStuff', nil)

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
    end

    it 'should return parsed JSON' do
      result = subject.post_request('com.example.service.doStuff', nil)

      result.should == { 'result' => 'ok' }
    end

    it 'should set content type to application/json' do
      subject.post_request('com.example.service.doStuff', nil)

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
        .with(headers: { 'Content-Type' => 'application/json' })
    end

    context 'with auth token' do
      it 'should pass the token in the header' do
        subject.post_request('com.example.service.doStuff', nil, 'qwerty99')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(headers: { 'Authorization' => 'Bearer qwerty99' })
      end
    end

    context 'without auth token' do
      it 'should not set the authorization header' do
        subject.post_request('com.example.service.doStuff', nil)

        WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.doStuff")
          .with(headers: { 'Authorization' => /.*/ })
      end
    end

    context 'if params are passed' do
      it 'should encode them as JSON in the body' do
        data = { repo: 'kate.dev', limit: 40, fields: ['name', 'posts'] }
        subject.post_request('com.example.service.doStuff', data)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: JSON.generate(data))
      end
    end

    context 'if params are nil' do
      it 'should send an empty body' do
        subject.post_request('com.example.service.doStuff', nil)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: '')
      end
    end

    context 'if the response has a 4xx status' do
      let(:response) {{ body: '{ "error": "message" }', status: 403 }}

      it 'should raise an error' do
        expect { subject.post_request('com.example.service.doStuff', nil) }.to raise_error(RuntimeError)
      end
    end
  end
end
