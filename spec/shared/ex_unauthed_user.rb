shared_examples "unauthenticated user" do
  let(:host) { subject.host }

  describe '#log_in' do
    it 'should raise AuthError' do
      expect { subject.log_in }.to raise_error(Minisky::AuthError)
    end
  end

  describe '#perform_token_refresh' do
    it 'should raise AuthError' do
      expect { subject.perform_token_refresh }.to raise_error(Minisky::AuthError)
    end
  end

  describe '#check_access' do
    it 'should raise AuthError' do
      expect { subject.check_access }.to raise_error(Minisky::AuthError)
    end
  end

  describe '#reset_tokens' do
    it 'should raise AuthError' do
      expect { subject.reset_tokens }.to raise_error(Minisky::AuthError)
    end
  end

  context '#user' do
    it 'should return nil' do
      subject.user.should be_nil
    end
  end

  context 'with auth headers off' do
    describe '#get_request' do
      it 'should not raise errors' do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.getTrends").to_return_json(body: { result: 123 })

        expect { subject.get_request('com.example.service.getTrends') }.to_not raise_error

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getTrends").once
      end
    end

    describe '#post_request' do
      it 'should not raise errors' do
        stub_request(:post, "https://#{host}/xrpc/com.example.service.createApp").to_return_json(body: { result: 123 })

        expect { subject.post_request('com.example.service.createApp') }.to_not raise_error

        WebMock.should have_requested(:post, "https://#{host}/xrpc/com.example.service.createApp").once
      end
    end

    describe '#fetch_all' do
      it 'should not raise errors' do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.listRepos")
          .to_return_json(body: { "repos": ["aaa"], "cursor": "x123" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.listRepos?cursor=x123")
          .to_return_json(body: { "repos": ["bbb"] })

        expect { subject.fetch_all('com.example.service.listRepos', field: 'repos') }.to_not raise_error

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.listRepos").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.listRepos?cursor=x123").once
      end
    end
  end

  context 'with sending auth headers turned on' do
    before do
      subject.send_auth_headers = true
    end

    describe '#get_request' do
      it 'should raise an error' do
        expect { subject.get_request('com.example.service.getTrends') }.to raise_error(Minisky::AuthError)
      end
    end

    describe '#post_request' do
      it 'should not raise errors' do
        expect { subject.post_request('com.example.service.createApp') }.to raise_error(Minisky::AuthError)
      end
    end

    describe '#fetch_all' do
      it 'should not raise errors' do
        expect { subject.fetch_all('com.example.service.listRepos', field: 'repos') }.to raise_error(Minisky::AuthError)
      end
    end
  end

  context 'with sending auth headers & auto manage tokens turned on' do
    before do
      subject.send_auth_headers = true
      subject.auto_manage_tokens = true
    end

    describe '#get_request' do
      it 'should raise an error' do
        expect { subject.get_request('com.example.service.getTrends') }.to raise_error(Minisky::AuthError)
      end
    end

    describe '#post_request' do
      it 'should not raise errors' do
        expect { subject.post_request('com.example.service.createApp') }.to raise_error(Minisky::AuthError)
      end
    end

    describe '#fetch_all' do
      it 'should not raise errors' do
        expect { subject.fetch_all('com.example.service.listRepos', field: 'repos') }.to raise_error(Minisky::AuthError)
      end
    end
  end
end
