require_relative 'ex_authorization'

shared_examples "post_request" do
  describe '#post_request' do
    let(:response) {{ body: '{ "result": "ok" }', headers: { 'Content-Type': 'application/json' }}}

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

    context 'if params is a string' do
      it 'should send that string' do
        subject.post_request('com.example.service.doStuff', 'hello world')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: 'hello world')
      end
    end

    context 'with headers' do
      it 'should include the custom headers' do
        subject.post_request('com.example.service.doStuff', 'blob', headers: { 'Blob-Type': 'blobby' })

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: 'blob', headers: { 'Blob-Type': 'blobby' })
      end

      it 'should set content type to application/json' do
        subject.post_request('com.example.service.doStuff', 'blob', headers: { 'Blob-Type': 'blobby' })

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: 'blob', headers: { 'Content-Type': 'application/json' })
      end
    end

    context 'with headers overriding Content-Type' do
      it 'should include the custom Content-Type' do
        subject.post_request('com.example.service.doStuff', 'blob', headers: { 'Content-Type': 'image/png' })

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: 'blob', headers: { 'Content-Type': 'image/png' })
      end
    end

    context 'with headers overriding content-type in lowercase' do
      it 'should still only include the custom Content-Type' do
        subject.post_request('com.example.service.doStuff', 'blob', headers: { 'content-type': 'image/jpeg' })

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: 'blob', headers: { 'content-type': 'image/jpeg' })
      end
    end

    context 'if the response has a 4xx status' do
      let(:response) {{ body: '{ "error": "message" }', status: 403, headers: { 'Content-Type': 'application/json' }}}

      it 'should raise an error' do
        expect { subject.post_request('com.example.service.doStuff') }.to raise_error(Minisky::ClientErrorResponse)
      end
    end

    context 'if the response has a 2xx status, but the response is not json' do
      let(:response) {{ body: 'ok', status: 201, headers: { 'Content-Type': 'text/plain' }}}

      it 'should not raise an error' do
        expect { subject.post_request('com.example.service.doStuff') }.to_not raise_error
      end

      it 'should return the body as a string' do
        subject.post_request('com.example.service.doStuff').should == 'ok'
      end
    end

    include_examples "authorization",
      request: ->(subject, params) { subject.post_request('com.example.service.doStuff', **params) },
      expected: ->(host) { [:post, "https://#{host}/xrpc/com.example.service.doStuff"] }
  end
end
