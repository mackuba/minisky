require_relative 'ex_requests_with_auth'
require_relative 'ex_bad_response'

shared_examples "get_request" do |include_auth_tests:|
  describe '#get_request' do
    before do
      stub_request(:get, %r(https://#{host}/xrpc/com.example.service.getStuff(\?.*)?)).to_return(response)
    end

    let(:response) {{ body: JSON.generate({ "result": 123 }), headers: { content_type: 'application/json' }}}

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

    context 'with nil params' do
      it 'should not append anything to the URL' do
        subject.get_request('com.example.service.getStuff', nil)

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
      end
    end

    context 'with empty params' do
      it 'should not append anything to the URL' do
        subject.get_request('com.example.service.getStuff', {})

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
      end
    end

    context 'with an array passed as param' do
      it 'should append one copy of the param for each item' do
        subject.get_request('com.example.service.getStuff', { profiles: ['john.foo', 'spam.zip'], reposts: true })

        WebMock.should have_requested(:get,
          "https://#{host}/xrpc/com.example.service.getStuff?profiles=john.foo&profiles=spam.zip&reposts=true").once
      end
    end

    context 'with headers' do
      it 'should include the custom headers' do
        subject.get_request('com.example.service.getStuff', { user: 'alf.gov' }, headers: { 'Food': 'cats' })

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff?user=alf.gov").once
         .with(headers: { 'Food' => 'cats' })
      end
    end

    context 'with an invalid method name' do
      it 'should raise an ArgumentError' do
        INVALID_METHOD_NAMES.each do |m|
          expect { subject.get_request(m) }.to raise_error(ArgumentError)
        end
      end
    end

    include_examples "bad response handling", :get, 'com.example.service.getStuff'

    if include_auth_tests
      include_examples "requests with authentication",
        request: ->(subject, params) { subject.get_request('com.example.service.getStuff', **params) },
        expected: ->(host) { [:get, "https://#{host}/xrpc/com.example.service.getStuff"] }
    end
  end

  describe 'host handling' do
    let(:response) {{ body: JSON.generate({ "result": 123 }), headers: { content_type: 'application/json' }}}

    context 'if host is just the server host without scheme' do
      before do
        subject.stubs(:host).returns('foo.example.com')
      end

      it 'should add https:// to the URL' do
        stub_request(:get, "https://foo.example.com/xrpc/com.example.service.getData").to_return(response)

        subject.get_request('com.example.service.getData')

        WebMock.should have_requested(:get, "https://foo.example.com/xrpc/com.example.service.getData").once
      end
    end

    context 'if host is a URL' do
      before do
        subject.stubs(:host).returns('http://localhost:3000')
      end

      it 'should just add /xrpc at the end' do
        stub_request(:get, "http://localhost:3000/xrpc/com.example.service.getData").to_return(response)

        subject.get_request('com.example.service.getData')

        WebMock.should have_requested(:get, "http://localhost:3000/xrpc/com.example.service.getData").once
      end
    end

    context 'if host is a URL with a trailing /' do
      before do
        subject.stubs(:host).returns('http://localhost:3000/')
      end

      it 'should not add an additional /' do
        stub_request(:get, "http://localhost:3000/xrpc/com.example.service.getData").to_return(response)

        subject.get_request('com.example.service.getData')

        WebMock.should have_requested(:get, "http://localhost:3000/xrpc/com.example.service.getData").once
      end
    end
  end

  describe 'endpoint handling' do
    let(:response) {{ body: JSON.generate({ "result": 123 }), headers: { content_type: 'application/json' }}}

    context 'if the method name is an NSID' do
      it 'should request /xrpc/method_name' do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.getData").to_return(response)

        subject.get_request('com.example.service.getData')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getData").once
      end
    end

    context 'if the method name is a URL string' do
      it 'should request that URL' do
        stub_request(:get, "https://app.example.com/.well-known/did.json").to_return(response)

        subject.get_request('https://app.example.com/.well-known/did.json')

        WebMock.should have_requested(:get, "https://app.example.com/.well-known/did.json").once
      end
    end

    context 'if the method name is a URI object' do
      it 'should request that URL' do
        stub_request(:get, "https://app.example.com/.well-known/oauth.json").to_return(response)

        subject.get_request(URI('https://app.example.com/.well-known/oauth.json'))

        WebMock.should have_requested(:get, "https://app.example.com/.well-known/oauth.json").once
      end
    end
  end

  context 'if a timeout option is set on the client instance' do
    it 'should pass that timeout to Net::HTTP' do
      subject.timeout = 17

      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response['Content-Type'] = 'text/plain'
      response.stubs(:body).returns('')

      Net::HTTP.expects(:start)
        .with(host, 443, { use_ssl: true, open_timeout: 17, read_timeout: 17 })
        .returns(response)

      subject.get_request('com.atproto.repo.getRecord')
    end
  end
end
