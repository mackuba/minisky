shared_examples "post_request" do
  describe '#post_request' do
    let(:response) {{ body: '{ "result": "ok" }' }}

    before do
      stub_request(:post, "https://#{host}/xrpc/com.example.service.doStuff").to_return(response)
    end

    it 'should make a request to the given XRPC endpoint' do
      subject.post_request('com.example.service.doStuff')

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
    end

    it 'should return parsed JSON' do
      result = subject.post_request('com.example.service.doStuff')

      result.should == { 'result' => 'ok' }
    end

    it 'should set content type to application/json' do
      subject.post_request('com.example.service.doStuff')

      WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
        .with(headers: { 'Content-Type' => 'application/json' })
    end

    [true, false, nil, :undefined, 'wtf'].each do |v|
      context "with send_auth_headers set to #{v.inspect}" do
        before do
          subject.send_auth_headers = v unless v == :undefined
        end

        context 'with an explicit auth token' do
          it 'should pass the token in the header' do
            subject.post_request('com.example.service.doStuff', auth: 'qwerty99')

            WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
              .with(headers: { 'Authorization' => 'Bearer qwerty99' })
          end
        end

        context 'with auth = false' do
          it 'should not set the authorization header' do
            subject.post_request('com.example.service.doStuff', auth: false)

            WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            WebMock.should_not have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff")
              .with(headers: { 'Authorization' => /.*/ })
          end
        end

        context 'with auth = nil' do
          it 'should not set the authorization header' do
            subject.post_request('com.example.service.doStuff', auth: nil)

            WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            WebMock.should_not have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff")
              .with(headers: { 'Authorization' => /.*/ })
          end
        end
      end
    end

    context 'without an auth parameter' do
      it 'should use the access token if send_auth_headers is true' do
        subject.send_auth_headers = true
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should use the access token if send_auth_headers is not set' do
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should use the access token if send_auth_headers is set to a truthy value' do
        subject.send_auth_headers = 'wtf'
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should not set the authorization header if send_auth_headers is false' do
        subject.send_auth_headers = false
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
        WebMock.should_not have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff")
          .with(headers: { 'Authorization' => /.*/ })
      end

      it 'should not set the authorization header if send_auth_headers is nil' do
        subject.send_auth_headers = nil
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
        WebMock.should_not have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff")
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

    context 'if params are not passed' do
      it 'should send an empty body' do
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: '')
      end
    end

    context 'if params are an explicit nil' do
      it 'should send an empty body' do
        subject.post_request('com.example.service.doStuff', nil)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: '')
      end
    end

    context 'if the response has a 4xx status' do
      let(:response) {{ body: '{ "error": "message" }', status: 403 }}

      it 'should raise an error' do
        expect { subject.post_request('com.example.service.doStuff') }.to raise_error(Minisky::ClientErrorResponse)
      end
    end
  end
end
