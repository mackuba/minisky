shared_examples "unauthenticated user" do
  let(:host) { subject.host }
  let(:expected_auth) { nil }

  describe '#log_in' do
    it 'should raise AuthError' do
      expect { subject.log_in }.to raise_error(Minisky::AuthError, /please provide a user id and password/)
    end
  end

  describe '#perform_token_refresh' do
    it 'should raise AuthError' do
      expect { subject.perform_token_refresh }.to raise_error(Minisky::AuthError, /refresh token is missing/)
    end
  end

  describe '#check_access' do
    it 'should raise AuthError' do
      expect { subject.check_access }.to raise_error(Minisky::AuthError, /User config is missing/)
    end
  end

  describe '#reset_tokens' do
    it 'should raise AuthError' do
      expect { subject.reset_tokens }.to raise_error(Minisky::AuthError, /User config is missing/)
    end
  end

  context '#user' do
    it 'should return nil' do
      subject.user.should be_nil
    end
  end

  shared_examples "request methods don't raise errors" do |auth_args|
    describe '#get_request' do
      it 'should not raise errors' do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.getTrends")
          .to_return_json(body: { result: 123 })

        expect { subject.get_request('com.example.service.getTrends', **auth_args) }.to_not raise_error

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getTrends").once
          .with_auth(expected_auth)
      end
    end

    describe '#post_request' do
      it 'should not raise errors' do
        stub_request(:post, "https://#{host}/xrpc/com.example.service.createApp")
          .to_return_json(body: { result: 123 })

        expect { subject.post_request('com.example.service.createApp', **auth_args) }.to_not raise_error

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.createApp").once
          .with_auth(expected_auth)
      end
    end

    describe '#fetch_all' do
      it 'should not raise errors' do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.listRepos")
          .to_return_json(body: { "repos": ["aaa"], "cursor": "x123" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.listRepos?cursor=x123")
          .to_return_json(body: { "repos": ["bbb"] })

        expect { subject.fetch_all('com.example.service.listRepos', field: 'repos', **auth_args) }.to_not raise_error

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.listRepos").once
          .with_auth(expected_auth)
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.listRepos?cursor=x123").once
          .with_auth(expected_auth)
      end
    end
  end

  shared_examples "request methods raise an error" do |auth_args, error_type, error_message|
    describe '#get_request' do
      it 'should raise an error' do
        expect { subject.get_request('com.example.service.getTrends', **auth_args) }.to raise_error(
          error_type, error_message
        )
      end
    end

    describe '#post_request' do
      it 'should raise an error' do
        expect { subject.post_request('com.example.service.createApp', **auth_args) }.to raise_error(
          error_type, error_message
        )
      end
    end

    describe '#fetch_all' do
      it 'should raise an error' do
        expect { subject.fetch_all('com.example.service.listRepos', field: 'repos', **auth_args) }.to raise_error(
          error_type, error_message
        )
      end
    end
  end

  context 'with auth headers off' do
    let(:expected_auth) { false }

    include_examples "request methods don't raise errors", {}
  end

  context 'with sending auth headers turned on' do
    before do
      subject.send_auth_headers = true
    end

    include_examples "request methods raise an error", {}, Minisky::AuthError, /access token is missing/
  end

  context 'with sending auth headers & auto manage tokens turned on' do
    before do
      subject.send_auth_headers = true
      subject.auto_manage_tokens = true
    end

    include_examples "request methods raise an error", {}, Minisky::AuthError, /User config is missing/
  end

  context 'with auto manage tokens turned on' do
    before do
      subject.auto_manage_tokens = true
    end

    let(:expected_auth) { false }

    include_examples "request methods don't raise errors", {}
  end

  context 'with auto manage tokens turned on and auth = true' do
    before do
      subject.auto_manage_tokens = true
    end

    include_examples "request methods raise an error", { auth: true }, Minisky::AuthError, /User config is missing/
  end

  context 'with auto manage tokens turned off and auth = true' do
    include_examples "request methods raise an error", { auth: true }, Minisky::AuthError, /access token is missing/
  end

  context 'with auto manage tokens turned on and auth = false' do
    before do
      subject.auto_manage_tokens = true
    end

    let(:expected_auth) { false }

    include_examples "request methods don't raise errors", { auth: false }
  end

  context 'with auth = false' do
    let(:expected_auth) { false }

    include_examples "request methods don't raise errors", { auth: false }
  end

  context 'with auto manage tokens turned on and auth = nil' do
    before do
      subject.auto_manage_tokens = true
    end

    let(:expected_auth) { false }

    include_examples "request methods don't raise errors", { auth: nil }
  end

  context 'with auth = nil' do
    let(:expected_auth) { false }

    include_examples "request methods don't raise errors", { auth: nil }
  end

  context 'with auto manage tokens turned on and auth = token' do
    before do
      subject.auto_manage_tokens = true
    end

    let(:expected_auth) { "Bearer foobar" }

    include_examples "request methods don't raise errors", { auth: 'foobar' }
  end

  context 'with auth = token' do
    let(:expected_auth) { "Bearer foobar" }

    include_examples "request methods don't raise errors", { auth: 'foobar' }
  end

  include_examples "get_request", include_auth_tests: false
  include_examples "post_request", include_auth_tests: false
  include_examples "fetch_all", include_auth_tests: false
end
