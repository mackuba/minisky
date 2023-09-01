require 'yaml'

describe Minisky do
  include FakeFS::SpecHelpers

  let(:host) { 'bsky.test' }

  context 'with a default config file name' do
    before do
      File.write('bluesky.yml', %(
        ident: john.foo
        pass: hunter2
        access_token: aatoken
        refresh_token: rrtoken
      ))
    end

    subject { Minisky.new(host) }

    let(:reloaded_config) { YAML.load(File.read('bluesky.yml')) }

    it 'should have a version number' do
      Minisky::VERSION.should_not be_nil
    end

    include_examples "Requests", 'bsky.test'
  end

  context 'with a custom config file name' do
    before do
      File.write('myconfig.yml', %(
        ident: john.foo
        pass: hunter2
        access_token: aatoken
        refresh_token: rrtoken
      ))
    end

    subject { Minisky.new(host, 'myconfig.yml') }

    let(:reloaded_config) { YAML.load(File.read('myconfig.yml')) }

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

      it "should save user's DID" do
        subject.log_in

        reloaded_config['did'].should == "did:plc:abracadabra"
      end

      it "should update the tokens in the config file" do
        subject.log_in

        reloaded_config['access_token'].should == 'aaaa1234'
        reloaded_config['refresh_token'].should == 'rrrr1234'
      end
    end
  end
end
