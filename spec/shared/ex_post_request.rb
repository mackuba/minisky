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

    context 'if data is passed as a hash' do
      let(:post_data) {
        { repo: 'kate.dev', limit: 40, fields: ['name', 'posts'] }
      }

      it 'should encode it as JSON in the body' do
        subject.post_request('com.example.service.doStuff', post_data)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: JSON.generate(post_data))
      end

      it 'should set content type to application/json' do
        subject.post_request('com.example.service.doStuff', post_data)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(headers: { 'Content-Type': 'application/json' })
      end

      context 'and custom content-type is set' do
        it 'should use that custom Content-Type' do
          subject.post_request('com.example.service.doStuff', post_data, headers: { 'Content-Type': 'application/graphql' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(headers: { 'Content-Type': 'application/graphql' })
        end
      end

      context 'and custom content-type in set in lowercase' do
        it 'should still use that custom Content-Type' do
          subject.post_request('com.example.service.doStuff', post_data, headers: { 'content-type': 'application/graphql' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(headers: { 'content-type': 'application/graphql' })
        end
      end

      context 'and other custom header is set' do
        it 'should add a json content type' do
          subject.post_request('com.example.service.doStuff', post_data, headers: { 'X-API-Token': '8768768768' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(headers: { 'Content-Type': 'application/json', 'X-API-Token': '8768768768' })
        end        
      end
    end

    context 'if data is not passed' do
      it 'should send an empty body' do
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: '')
      end

      it 'should not set content type' do
        subject.post_request('com.example.service.doStuff')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with { |req| req.headers.all? { |k, v| k.downcase != 'content-type' }}
      end

      context 'and custom content-type is set' do
        it 'should include the custom Content-Type' do
          subject.post_request('com.example.service.doStuff', headers: { 'Content-Type': 'image/png' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(body: '', headers: { 'Content-Type': 'image/png' })
        end
      end

      context 'and custom content-type in set in lowercase' do
        it 'should include the custom Content-Type' do
          subject.post_request('com.example.service.doStuff', headers: { 'content-type': 'image/jpeg' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(body: '', headers: { 'content-type': 'image/jpeg' })
        end
      end

      context 'and other custom header is set' do
        it 'should not add content type' do
          subject.post_request('com.example.service.doStuff', headers: { 'Blob-Type': 'blobby' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with { |req| req.headers.all? { |k, v| k.downcase != 'content-type' } && req.headers['Blob-Type'] == 'blobby' }
        end        
      end
    end

    context 'if data is an explicit nil' do
      it 'should send an empty body' do
        subject.post_request('com.example.service.doStuff', nil)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: '')
      end

      it 'should not set content type' do
        subject.post_request('com.example.service.doStuff', nil)

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with { |req| req.headers.all? { |k, v| k.downcase != 'content-type' }}
      end

      context 'and custom content-type is set' do
        it 'should include the custom Content-Type' do
          subject.post_request('com.example.service.doStuff', nil, headers: { 'Content-Type': 'image/png' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(body: '', headers: { 'Content-Type': 'image/png' })
        end
      end

      context 'and custom content-type in set in lowercase' do
        it 'should include the custom Content-Type' do
          subject.post_request('com.example.service.doStuff', nil, headers: { 'content-type': 'image/jpeg' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(body: '', headers: { 'content-type': 'image/jpeg' })
        end
      end

      context 'and other custom header is set' do
        it 'should not add content type' do
          subject.post_request('com.example.service.doStuff', nil, headers: { 'Blob-Type': 'blobby' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with { |req| req.headers.all? { |k, v| k.downcase != 'content-type' } && req.headers['Blob-Type'] == 'blobby' }
        end        
      end
    end

    context 'if data is a string' do
      it 'should send that string' do
        subject.post_request('com.example.service.doStuff', 'hello world')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with(body: 'hello world')
      end

      it 'should not set content type' do
        subject.post_request('com.example.service.doStuff', 'hello world')

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
          .with { |req| req.headers.all? { |k, v| k.downcase != 'content-type' }}
      end

      context 'and custom content-type is set' do
        it 'should include the custom Content-Type' do
          subject.post_request('com.example.service.doStuff', 'blob', headers: { 'Content-Type': 'image/png' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(body: 'blob', headers: { 'Content-Type': 'image/png' })
        end
      end

      context 'and custom content-type in set in lowercase' do
        it 'should include the custom Content-Type' do
          subject.post_request('com.example.service.doStuff', 'blob', headers: { 'content-type': 'image/jpeg' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with(body: 'blob', headers: { 'content-type': 'image/jpeg' })
        end
      end

      context 'and other custom header is set' do
        it 'should not add content type' do
          subject.post_request('com.example.service.doStuff', 'blob', headers: { 'Blob-Type': 'blobby' })

          WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.doStuff").once
            .with { |req| req.headers.all? { |k, v| k.downcase != 'content-type' } && req.headers['Blob-Type'] == 'blobby' }
        end        
      end
    end

    context 'with both string data and query params' do
      it 'should add the params to the URL' do
        stub_request(:post, "https://#{host}/xrpc/app.bsky.video.uploadVideo?name=rickroll.mp4").to_return(response)

        subject.post_request('app.bsky.video.uploadVideo', '/\/\/\/\/\/\/', params: { name: 'rickroll.mp4' })

        WebMock.should have_requested(:post, "https://#{host}/xrpc/app.bsky.video.uploadVideo?name=rickroll.mp4").once
          .with(body: '/\/\/\/\/\/\/')
      end
    end

    context 'with an invalid method name' do
      it 'should raise an ArgumentError' do
        INVALID_METHOD_NAMES.each do |m|
          expect { subject.post_request(m) }.to raise_error(ArgumentError)
        end
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
