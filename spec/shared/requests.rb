require_relative 'get_request'
require_relative 'post_request'
require_relative 'fetch_all'

shared_examples "Requests" do |host|
  let(:host) { host }

  before do
    subject.auto_manage_tokens = false
  end

  it 'should load config from a file' do
    subject.user.id.should == 'john.foo'
    subject.user.access_token.should == 'aatoken'
    subject.user.refresh_token.should == 'rrtoken'
  end

  it 'should have a user object wrapping the config' do
    subject.config['something'] = 'some value'

    subject.user.something.should == 'some value'
  end

  describe '#log_in' do
    let(:response_json) { JSON.generate(
      "did": "did:plc:abracadabra",
      "accessJwt": "aaaa1234",
      "refreshJwt": "rrrr1234"
    )}

    before do
      stub_request(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
        .to_return(body: response_json)
    end

    it 'should make a request to com.atproto.server.createSession' do
      subject.log_in

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
        .once.with(body: %({"identifier":"john.foo","password":"hunter2"}))
    end

    [true, false, nil, :undefined, 'wtf'].each do |v|
      context "with send_auth_headers set to #{v.inspect}" do
        it 'should not set authentication header' do
          subject.send_auth_headers = v unless v == :undefined
          subject.log_in

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
          WebMock.should_not have_requested(:post, "https://#{host}/xrpc/com.atproto.server.createSession")
            .with(headers: { 'Authorization' => /.*/ })
        end
      end
    end

    it "should save user's DID" do
      subject.log_in

      reloaded_config['did'].should == "did:plc:abracadabra"
    end

    it "should update the tokens in the config file" do
      subject.log_in

      reloaded_config['access_token'].should == 'aaaa1234'
      reloaded_config['refresh_token'].should == 'rrrr1234'
    end

    it 'should return the response json' do
      subject.log_in.should == JSON.parse(response_json)
    end
  end

  describe '#perform_token_refresh' do
    let(:response_json) { JSON.generate(
      "accessJwt": "aaaa1234",
      "refreshJwt": "rrrr1234"      
    )}

    before do
      stub_request(:post, "https://#{host}/xrpc/com.atproto.server.refreshSession")
        .to_return(body: response_json)
    end

    it 'should make a request to com.atproto.server.refreshSession' do
      subject.perform_token_refresh

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.refreshSession")
        .once.with(body: '')
    end

    [true, false, nil, :undefined, 'wtf'].each do |v|
      context "with send_auth_headers set to #{v.inspect}" do
        it 'should authenticate with the refresh token' do
          subject.send_auth_headers = v unless v == :undefined
          subject.perform_token_refresh

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.atproto.server.refreshSession")
            .once.with(headers: { 'Authorization' => 'Bearer rrtoken' })
        end
      end
    end

    it "should update the tokens in the config file" do
      subject.perform_token_refresh

      reloaded_config['access_token'].should == 'aaaa1234'
      reloaded_config['refresh_token'].should == 'rrrr1234'
    end

    it 'should return the response json' do
      subject.perform_token_refresh.should == JSON.parse(response_json)
    end
  end

  include_examples "get_request"
  include_examples "post_request"
  include_examples "fetch_all"
end
