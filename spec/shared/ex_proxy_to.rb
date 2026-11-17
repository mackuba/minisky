shared_examples "atproto-proxy" do
  describe '#proxy' do
    let(:appview) { 'did:web:api.bsky.app#bsky_appview' }
    let(:labeler) { 'did:plc:ewvi7nxzyoun6zhxrhs64oiz#atproto_labeler' }

    context 'configured with an exact NSID' do
      it 'should add the atproto-proxy header for the given service to GET requests' do
        subject.proxy('app.bsky.getFeedV2', to: appview)

        stub_request(:get, "#{subject.base_url}/app.bsky.getFeedV2")
          .with(headers: { 'atproto-proxy' => appview }).to_return_json(body: {})

        stub_request(:get, "#{subject.base_url}/app.bsky.getFeedV20")
          .with { |request| !request.headers.key?('Atproto-Proxy') }.to_return_json(body: {})

        subject.get_request('app.bsky.getFeedV2')
        subject.get_request('app.bsky.getFeedV20')
      end

      it 'should add the header to POST requests' do
        subject.proxy('app.bsky.feed.putPreferences', to: appview)

        stub_request(:post, "#{subject.base_url}/app.bsky.feed.putPreferences")
          .with(body: '{"preferences":[]}', headers: {
            'atproto-proxy' => appview, 'Authorization' => 'Bearer token', 'Content-Type' => 'application/json'
          }).to_return_json(body: {})

        stub_request(:post, "#{subject.base_url}/app.bsky.feed.putPreferences2")
          .with { |request| !request.headers.key?('Atproto-Proxy') }.to_return_json(body: {})

        subject.post_request('app.bsky.feed.putPreferences', { preferences: [] }, auth: 'token')
        subject.post_request('app.bsky.feed.putPreferences2', { preferences: [] }, auth: 'token')
      end
    end

    context 'configured with a prefix and wildcard' do
      it 'should add the atproto-proxy header for any matching endpoint' do
        subject.proxy('app.*', to: labeler)

        stub_request(:post, "#{subject.base_url}/app.bsky.feed.putPreferences")
          .with(body: '{"preferences":[]}', headers: {
            'atproto-proxy' => labeler, 'Authorization' => 'Bearer token', 'Content-Type' => 'application/json'
          }).to_return_json(body: {})

        subject.post_request('app.bsky.feed.putPreferences', { preferences: [] }, auth: 'token')
      end

      it 'should make the wildcard match only at a segment boundary' do
        subject.proxy('app.bsky.*', to: appview)

        [
          "#{subject.base_url}/app.bsky",
          "#{subject.base_url}/app.bskyfeed.getTimeline",
          "#{subject.base_url}/appXbsky.feed.getTimeline",
        ].each do |url|
          stub_request(:get, url).with { |request| !request.headers.key?('Atproto-Proxy') }.to_return_json(body: {})
        end

        subject.get_request("#{subject.base_url}/app.bsky")
        subject.get_request('app.bskyfeed.getTimeline')
        subject.get_request('appXbsky.feed.getTimeline')
      end

      it 'should only add the header for requests with NSID as the first argument' do
        subject.proxy('app.bsky.*', to: appview)

        stub_request(:get, 'https://other.example.com/xrpc/app.bsky.feed.getTimeline')
          .with { |request| !request.headers.key?('Atproto-Proxy') }.to_return_json(body: {})

        subject.get_request(URI('https://other.example.com/xrpc/app.bsky.feed.getTimeline'), auth: false)
      end
    end

    context 'with multiple proxy services' do
      it 'should use the first matching rule when an exact NSID and a wildcard overlap' do
        subject.proxy('app.bsky.*', to: appview)
        subject.proxy('app.bsky.feed.getTimeline', to: labeler)

        stub_request(:get, "#{subject.base_url}/app.bsky.feed.getTimeline")
          .with(headers: { 'atproto-proxy' => appview }).to_return_json(body: {})

        subject.get_request('app.bsky.feed.getTimeline')
      end
    end

    context 'with an explicit proxy header' do
      it 'should let the explicit header override the configured value' do
        subject.proxy('app.bsky.*', to: appview)

        stub_request(:get, "#{subject.base_url}/app.bsky.feed.getTimeline")
          .with(headers: { 'atproto-proxy' => labeler }).to_return_json(body: {})

        subject.get_request('app.bsky.feed.getTimeline', headers: { 'atproto-proxy' => labeler })
      end      
    end

    it 'should accept an encoded localhost port in a did:web service reference' do
      service = 'did:web:localhost%3A3000#app-view'
      subject.proxy('app.bsky.42-feed.*', to: service)

      subject.proxy_services.values.should == [service]
    end

    it "should reject invalid NSID patterns" do
      [
        nil, :app, '', '*', '.*', 'app.bsky', 'app.*.feed', 'app.bsky*', 'app.bsky.**',
       'app..*', '3app.bsky.*', 'app.bsky-.*', 'app.bsky.bad_name', 'app.bsky.bad-name',
       'app.bsky.3feed', "app.bsky.feed\n", 'app.bsky.(feed|actor).*', "#{'a' * 64}.*",
       "#{(['a' * 63] * 4).join('.')}.*"
      ].each do |pattern|
        expect { subject.proxy(pattern, to: appview) }.to raise_error(ArgumentError, /Invalid proxy NSID pattern/)
      end

      subject.proxy_services.should be_empty
    end

    it "should rejects invalid service IDs" do
      subject.proxy('app.bsky.*', to: appview)

      [
        nil, :appview, '', 'api.bsky.app#bsky_appview', 'did:web:api.bsky.app', 'did:web:api.bsky.app#',
       'did:web:#bsky_appview', 'did:web:api..bsky.app#bsky_appview', 'did:web:api.bsky.app:admin#view',
       'did:web:localhost:3000#view', 'did:plc:abc123#bsky_appview', 'did:web:api.bsky.app#view#extra',
       'did:web:api.bsky.app#app view', 'did:web:api.bsky.app#app%QQ', "did:web:api.bsky.app#view\r\n"
      ].each do |service|
        expect { subject.proxy('app.bsky.*', to: service) }.to raise_error(ArgumentError, /Invalid proxy service/)
      end

      subject.proxy_services.values.should == [appview]
    end
  end
end
