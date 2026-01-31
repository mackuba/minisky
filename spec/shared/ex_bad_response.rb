shared_examples "bad response handling" do |method, endpoint|
  context 'with a bad response' do
    let(:method) { method }
    let(:endpoint) { endpoint }

    def make_request(**kwargs)
      subject.send("#{method}_request", endpoint, **kwargs)
    end

    context 'if the response has a 4xx status' do
      let(:response) {{
        body: JSON.generate(error: 'BadReq', message: 'This request was bad'),
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      }}

      it 'should raise a ClientErrorResponse error' do
        expect { make_request }.to raise_error { |err|
          err.should be_a(Minisky::ClientErrorResponse)
          err.status.should == 403
          err.data.should be_a(Hash)
          err.error_type.should == 'BadReq'
          err.error_message.should == 'This request was bad'
        }
      end
    end

    context 'if the response has a 5xx status' do
      let(:response) {{
        body: JSON.generate(error: 'Boom', message: 'Server exploded'),
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }}

      it 'should raise a ServerErrorResponse error' do
        expect { make_request }.to raise_error { |err|
          err.should be_a(Minisky::ServerErrorResponse)
          err.status.should == 500
          err.data.should be_a(Hash)
          err.error_type.should == 'Boom'
          err.error_message.should == 'Server exploded'
        }
      end
    end

    context 'if the response is a redirect' do
      let(:response) {{ status: 302, headers: { 'Location': 'https://google.com' }}}

      it 'should raise an UnexpectedRedirect error' do
        expect { make_request }.to raise_error { |err|
          err.should be_a(Minisky::UnexpectedRedirect)
          err.status.should == 302
          err.data.should be_a(Hash)
          err.location.should == 'https://google.com'
        }
      end
    end

    context 'if the response is an ExpiredToken error' do
      let(:response) {{
        body: JSON.generate(error: 'ExpiredToken', message: 'Your token has expired'),
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      }}

      it 'should raise an ExpiredTokenError error' do
        expect { make_request }.to raise_error { |err|
          err.should be_a(Minisky::ExpiredTokenError)
          err.status.should == 401
          err.data.should be_a(Hash)
          err.error_type.should == 'ExpiredToken'
          err.error_message.should == 'Your token has expired'
        }
      end
    end

    context 'if the bad response is not json' do
      let(:response) {{
        body: '<html>wtf</html>',
        status: 503
      }}

      it 'should raise an error with the response body' do
        expect { make_request }.to raise_error { |err|
          err.should be_a(Minisky::BadResponse)
          err.status.should == 503
          err.data.should == '<html>wtf</html>'
          err.error_type.should be_nil
          err.error_message.should be_nil
        }
      end
    end

    context 'if the response is not json, but has a 2xx status' do
      let(:response) {{ body: 'ok', status: 201, headers: { 'Content-Type': 'text/plain' }}}

      it 'should not raise an error' do
        expect { make_request }.to_not raise_error
      end

      it 'should return the body as a string' do
        result = make_request
        result.should == 'ok'
      end
    end
  end
end
