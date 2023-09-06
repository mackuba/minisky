shared_examples "get_request" do
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

    context 'with nil params' do
      it 'should not append anything to the URL' do
        subject.get_request('com.example.service.getStuff', nil)

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

    [true, false, nil, :undefined, 'wtf'].each do |v|
      context "with send_auth_headers set to #{v.inspect}" do
        before do
          subject.send_auth_headers = v unless v == :undefined
        end

        context 'with an explicit auth token' do
          it 'should pass the token in the header' do
            subject.get_request('com.example.service.getStuff', auth: 'token777')

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
              .with(headers: { 'Authorization' => 'Bearer token777' })
          end
        end

        context 'with auth = true' do
          it 'should use the access token' do
            subject.get_request('com.example.service.getStuff', auth: true)

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
              .with(headers: { 'Authorization' => 'Bearer aatoken' })
          end
        end

        context 'with auth = false' do
          it 'should not set the authorization header' do
            subject.get_request('com.example.service.getStuff', auth: false)

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
            WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff")
              .with(headers: { 'Authorization' => /.*/ })
          end
        end

        context 'with auth = nil' do
          it 'should not set the authorization header' do
            subject.get_request('com.example.service.getStuff', auth: nil)

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
            WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff")
              .with(headers: { 'Authorization' => /.*/ })
          end
        end
      end
    end

    context 'without an auth parameter' do
      it 'should use the access token if send_auth_headers is true' do
        subject.send_auth_headers = true
        subject.get_request('com.example.service.getStuff')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should use the access token if send_auth_headers is not set' do
        subject.get_request('com.example.service.getStuff')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should use the access token if send_auth_headers is set to a truthy value' do
        subject.send_auth_headers = 'wtf'
        subject.get_request('com.example.service.getStuff')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should should not set the authorization header if send_auth_headers is false' do
        subject.send_auth_headers = false
        subject.get_request('com.example.service.getStuff')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
        WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff")
          .with(headers: { 'Authorization' => /.*/ })
      end

      it 'should should not set the authorization header if send_auth_headers is nil' do
        subject.send_auth_headers = nil
        subject.get_request('com.example.service.getStuff')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
        WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff")
          .with(headers: { 'Authorization' => /.*/ })
      end
    end
  end
end
