# frozen_string_literal: true

require 'tmpdir'
require_relative 'fake_pds'

describe 'Minisky interacting with a PDS' do
  subject(:client) { Minisky.new(pds.url, @config_file, timeout: 5) }

  let(:pds) { FakePDS.new }

  let(:get_nsid) { 'app.bsky.actor.getProfiles' }
  let(:post_nsid) { 'com.atproto.repo.createRecord' }
  let(:list_nsid) { 'com.atproto.repo.listRecords' }
  let(:authorization) { nil }
  let(:second_cursor) { 'page 2+/=' }

  let(:fetch_all_pages) {
    {
      nil => { records: [1, 2], cursor: second_cursor },
      second_cursor => { records: [3, 4], cursor: 'page 3' },
      'page 3' => { records: [5] }
    }
  }

  around do |example|
    pds.run do
      origin = URI(pds.url)

      WebMock.disable_net_connect!(allow: ->(uri) do
        uri.scheme == origin.scheme && uri.host == origin.host && uri.port == origin.port
      end)

      example.run
    end
  ensure
    WebMock.disable_net_connect!
  end

  def serve_fetch_all_pages
    responses = fetch_all_pages
    pds.on(:get, list_nsid) { |request| responses.fetch(request.query.to_h['cursor']) }
  end

  shared_examples 'requests over HTTP' do
    it 'should send a GET with query parameters and custom headers' do
      profiles = { 'profiles' => [{ 'handle' => 'alice.test' }] }
      pds.on(:get, get_nsid, returns: { body: profiles })

      result = client.get(get_nsid, { actors: ['alice.test', 'did:web:bob.test'] },
                          headers: { 'X-Trace-Id' => 'profiles' })

      result.should == profiles

      pds.requests.should contain_exactly(have_attributes(
        method: 'GET',
        path: "/xrpc/#{get_nsid}",
        query: [['actors', 'alice.test'], ['actors', 'did:web:bob.test']],
        headers: include('x-trace-id' => ['profiles']),
        body: ''
      ))

      pds.requests.first.headers['authorization'].should == authorization
    end

    it 'should send a POST with JSON data, query parameters, and custom headers' do
      data = { 'repo' => 'alice.test', 'record' => { 'text' => 'Gm ☀️' } }
      response = { 'uri' => 'at://alice.test/app.bsky.feed.post/123' }
      pds.on(:post, post_nsid, returns: { status: 201, body: response })

      result = client.post(post_nsid, data, params: { validate: true }, headers: { 'X-Trace-Id' => 'create' })

      result.should == response

      pds.requests.should contain_exactly(have_attributes(
        method: 'POST',
        path: "/xrpc/#{post_nsid}",
        query: [['validate', 'true']],
        json_body: data,
        headers: include('content-type' => ['application/json'], 'x-trace-id' => ['create'])
      ))

      pds.requests.first.headers['authorization'].should == authorization
    end

    it 'should fetch all pages with the original query and headers on each request' do
      serve_fetch_all_pages
      params = { repo: 'alice.test', limit: 2 }

      result = client.fetch_all(list_nsid, params, field: 'records', headers: { 'X-Trace-Id' => 'list' })

      result.should == [1, 2, 3, 4, 5]
      params.should == { repo: 'alice.test', limit: 2 }

      pds.requests.map(&:query).map(&:to_h).should == [
        { 'repo' => 'alice.test', 'limit' => '2' },
        { 'repo' => 'alice.test', 'limit' => '2', 'cursor' => second_cursor },
        { 'repo' => 'alice.test', 'limit' => '2', 'cursor' => 'page 3' }
      ]

      pds.requests.should all(have_attributes(
        method: 'GET',
        path: "/xrpc/#{list_nsid}",
        headers: include('x-trace-id' => ['list'])
      ))

      pds.requests.map { |r| r.headers['authorization'] }.should == [authorization] * 3
    end
  end

  context 'without a user config' do
    include_examples 'requests over HTTP'

    it 'should send binary POST data unchanged with the supplied content type' do
      nsid = 'com.atproto.repo.uploadBlob'
      data = "\x00\xFF\x0D\x0A".b
      pds.on(:post, nsid, returns: { body: 'uploaded' })

      result = client.post(nsid, data, headers: { 'Content-Type' => 'application/octet-stream' })
      result.should == 'uploaded'

      pds.requests.should contain_exactly(have_attributes(
        method: 'POST',
        path: "/xrpc/#{nsid}",
        body: data,
        headers: include('content-type' => ['application/octet-stream'])
      ))
    end
  end

  context 'with a user config' do
    let(:credentials) {{ 'id' => 'alice.test', 'pass' => 'test-password' }}
    let(:config) { credentials }

    around do |example|
      Dir.mktmpdir('minisky-integration-') do |directory|
        @config_file = File.join(directory, 'client.yml')
        example.run
      end
    end

    before do
      File.write(@config_file, YAML.dump(config))
    end

    context 'with an existing session' do
      let(:access_token) { make_token(Time.now + 3600) }
      let(:config) { credentials.merge('access_token' => access_token, 'refresh_token' => 'refresh-token') }
      let(:authorization) { ["Bearer #{access_token}"] }

      include_examples 'requests over HTTP'
    end

    context 'when logging in automatically' do
      let(:session_nsid) { 'com.atproto.server.createSession' }
      let(:refresh_nsid) { 'com.atproto.server.refreshSession' }
      let(:profile) {{ 'profiles' => [{ 'handle' => 'alice.test' }] }}
      let(:did) { 'did:plc:abcdefghijklmnopqrstuvwx' }

      before do
        pds.on(:get, get_nsid, returns: { body: profile })
      end

      def serve_login_endpoint(access_token:)
        pds.on(:post, session_nsid, returns: {
          body: { did: did, accessJwt: access_token, refreshJwt: 'first-refresh-token' }
        })
      end

      it 'should log in, use the first access token, then refresh it before the next request after expiry' do
        now = Time.now

        # first request with login

        access_token = make_token(now + 3600)
        serve_login_endpoint(access_token: access_token)

        result = client.get(get_nsid)
        result.should == profile

        reloaded_config = YAML.safe_load(File.read(@config_file))
        reloaded_config.should == credentials.merge(
          'did' => did, 'access_token' => access_token, 'refresh_token' => 'first-refresh-token'
        )


        # second request which triggers a refresh

        refreshed_token = make_token(now + 10_800)

        pds.on(:post, refresh_nsid, returns: {
          body: { accessJwt: refreshed_token, refreshJwt: 'second-refresh-token' }
        })

        Time.stubs(:now).returns(now + 7200)

        result = client.get(get_nsid)
        result.should == profile

        reloaded_config = YAML.safe_load(File.read(@config_file))
        reloaded_config.should == credentials.merge(
          'did' => did, 'access_token' => refreshed_token, 'refresh_token' => 'second-refresh-token'
        )

        pds.requests.should match([
          have_attributes(
            method: 'POST',
            path: "/xrpc/#{session_nsid}",
            json_body: { 'identifier' => 'alice.test', 'password' => 'test-password' }
          ),
          have_attributes(
            method: 'GET',
            path: "/xrpc/#{get_nsid}",
            headers: include('authorization' => ["Bearer #{access_token}"])
          ),
          have_attributes(
            method: 'POST',
            path: "/xrpc/#{refresh_nsid}",
            body: '',
            headers: include('authorization' => ['Bearer first-refresh-token'])
          ),
          have_attributes(
            method: 'GET',
            path: "/xrpc/#{get_nsid}",
            headers: include('authorization' => ["Bearer #{refreshed_token}"])
          )
        ])

        pds.requests.first.headers.should_not have_key('authorization')
      end

      it 'should not fail trying to decode a token which is an opaque string' do
        serve_login_endpoint(access_token: 'opaque-token')

        client.get(get_nsid).should == profile
        client.get(get_nsid).should == profile

        reloaded_config = YAML.safe_load(File.read(@config_file))
        reloaded_config.should include(
          'access_token' => 'opaque-token', 'refresh_token' => 'first-refresh-token'
        )

        pds.requests.map(&:path).should == ["/xrpc/#{session_nsid}", "/xrpc/#{get_nsid}", "/xrpc/#{get_nsid}"]

        pds.requests.map { |r| r.headers['authorization'] }.should == [
          nil, ['Bearer opaque-token'], ['Bearer opaque-token']
        ]
      end
    end
  end

  context 'with fetch limits' do
    before do
      serve_fetch_all_pages
    end

    it 'should stop after max_pages even when the last page has a cursor' do
      result = client.fetch_all(list_nsid, field: 'records', max_pages: 2)
      result.should == [1, 2, 3, 4]

      pds.requests.map(&:query).should == [[], [['cursor', second_cursor]]]
    end

    it 'should stop at a break condition and filter the matching records' do
      result = client.fetch_all(list_nsid, field: 'records', break_when: ->(record) { record > 3 })
      result.should == [1, 2, 3]

      pds.requests.map(&:query).should == [[], [['cursor', second_cursor]]]
    end

    context 'with an empty intermediate page' do
      let(:fetch_all_pages) {
        super().merge(second_cursor => { records: [], cursor: 'page 3' })
      }

      it 'should follow the cursor by default' do
        result = client.fetch_all(list_nsid, field: 'records')
        result.should == [1, 2, 5]

        pds.requests.map(&:query).should == [[], [['cursor', second_cursor]], [['cursor', 'page 3']]]
      end

      it 'should stop on an empty page when configured to do so' do
        client.stop_fetch_on_empty_page = true

        result = client.fetch_all(list_nsid, field: 'records')
        result.should == [1, 2]

        pds.requests.map(&:query).should == [[], [['cursor', second_cursor]]]
      end
    end
  end

  it 'should send the configured proxy header on matching GET, POST, and fetch requests' do
    appview = 'did:web:appview.test#bsky_appview'
    records = 'did:web:records.test#repo'
    unproxied_nsid = 'com.atproto.server.describeServer'

    client.proxy(get_nsid, to: appview)
    client.proxy('com.atproto.repo.*', to: records)

    pds.on(:get, get_nsid, returns: { body: {} })
    pds.on(:post, post_nsid, returns: { body: {} })
    pds.on(:get, unproxied_nsid, returns: { body: {} })
    serve_fetch_all_pages

    client.get(get_nsid)
    client.post(post_nsid, {})
    client.fetch_all(list_nsid, field: 'records', max_pages: 2)
    client.get(unproxied_nsid)

    pds.requests.map { |r| r.headers['atproto-proxy'] }.should == [
      [appview], [records], [records], [records], nil
    ]
  end

  context 'with error responses' do
    it 'should raise on a redirect and leave the destination unrequested' do
      location = "#{pds.url}/xrpc/#{list_nsid}"
      pds.on(:get, get_nsid, returns: { status: 302, headers: { 'Location' => location }})
      serve_fetch_all_pages

      expect { client.get(get_nsid) }.to raise_error(Minisky::UnexpectedRedirect) do |error|
        error.status.should == 302
        error.location.should == location
      end

      pds.requests.map(&:path).should == ["/xrpc/#{get_nsid}"]
    end

    it 'should raise a client error with the parsed JSON error details for 4xx' do
      body = { 'error' => 'InvalidRequest', 'message' => 'Record is missing a required field' }
      pds.on(:post, post_nsid, returns: { status: 400, body: body })

      expect { client.post(post_nsid, {}) }.to raise_error(Minisky::ClientErrorResponse) do |error|
        error.status.should == 400
        error.data.should == body
        error.error_type.should == 'InvalidRequest'
        error.error_message.should == 'Record is missing a required field'
      end
    end

    it 'should raise an expired-token error when the PDS rejects an opaque bearer token' do
      body = { 'error' => 'ExpiredToken', 'message' => 'Token has expired' }
      pds.on(:get, get_nsid, returns: { status: 401, body: body })

      expect { client.get(get_nsid, auth: 'opaque-token') }.to raise_error(Minisky::ExpiredTokenError) do |error|
        error.status.should == 401
        error.data.should == body
        error.error_type.should == 'ExpiredToken'
      end

      pds.requests.should contain_exactly(have_attributes(
        headers: include('authorization' => ['Bearer opaque-token'])
      ))
    end

    it 'should raise a server error on 5xx, and should accept a plain-text body' do
      pds.on(:get, get_nsid, returns: { status: 503, body: 'Temporarily unavailable' })

      expect { client.get(get_nsid) }.to raise_error(Minisky::ServerErrorResponse) do |error|
        error.status.should == 503
        error.data.should == 'Temporarily unavailable'
      end
    end
  end

  it 'should keep outbound HTTP blocked for hosts other than the simulated PDS' do
    outside = 'http://outside.example.test/'

    pds.on(:get, get_nsid) {
      { outside_allowed: !!WebMock.net_connect_allowed?(outside) }
    }

    client.get(get_nsid).should == { 'outside_allowed' => false }

    expect { client.get(outside) }.to raise_error(WebMock::NetConnectNotAllowedError)
    expect { client.get('http://127.0.0.1:1/') }.to raise_error(WebMock::NetConnectNotAllowedError)
  end
end
