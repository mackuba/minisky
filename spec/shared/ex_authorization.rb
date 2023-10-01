shared_examples 'authorization' do |http_method, request:, expected:|
  let(:request) { request }
  let(:expected) { expected }

  def make_request(auth:)
    request.call(subject, { auth: auth })
  end

  def make_request_without_auth
    request.call(subject, {})
  end

  def expected_calls
    calls = expected.call(host)
    calls[0].is_a?(Array) ? calls : [calls]
  end

  def self.with_access_token(*modes, &definitions)
    modes.each do |m|
      case m
      when :unchanged
        instance_eval(&definitions)
      when :nil
        context "when access_token is nil" do
          before { subject.user.access_token = nil }
          instance_eval(&definitions)
        end
      when :deleted
        context "when access_token is not provided" do
          before { subject.config.delete('access_token') }
          instance_eval(&definitions)
        end
      else
        raise "Unknown mode #{m}"
      end
    end
  end

  [true, false, nil, :undefined].each do |v|
    context "with send_auth_headers set to #{v.inspect}" do
      before do
        subject.send_auth_headers = v unless v == :undefined
      end

      context 'with an explicit auth token' do
        with_access_token(:unchanged, :nil, :deleted) do
          it 'should pass the token in the header' do
            make_request(auth: 'qwerty99')

            expected_calls.each do |method, url|
              WebMock.should have_requested(method, url).once.with(headers: { 'Authorization' => 'Bearer qwerty99' })
            end
          end
        end
      end

      context 'with auth = true' do
        it 'should use the access token' do
          make_request(auth: true)

          expected_calls.each do |method, url|
            WebMock.should have_requested(method, url).once.with(headers: { 'Authorization' => 'Bearer aatoken' })
          end
        end

        with_access_token(:nil, :deleted) do
          it 'should raise AuthError' do
            expect { make_request(auth: true) }.to raise_error(Minisky::AuthError)

            expected_calls.each { |method, url| WebMock.should_not have_requested(method, url) }
          end
        end
      end

      context 'with auth = false' do
        with_access_token(:unchanged, :nil, :deleted) do
          it 'should not set the authorization header' do
            make_request(auth: false)

            expected_calls.each do |method, url|
              WebMock.should have_requested(method, url).once
              WebMock.should_not have_requested(method, url).with(headers: { 'Authorization' => /.*/ })
            end
          end
        end
      end

      context 'with auth = nil' do
        with_access_token(:unchanged, :nil, :deleted) do
          it 'should not set the authorization header' do
            make_request(auth: nil)

            expected_calls.each do |method, url|
              WebMock.should have_requested(method, url).once
              WebMock.should_not have_requested(method, url).with(headers: { 'Authorization' => /.*/ })
            end
          end
        end
      end
    end
  end

  context 'without an auth parameter' do
    it 'should use the access token if send_auth_headers is true' do
      subject.send_auth_headers = true

      make_request_without_auth

      expected_calls.each do |method, url|
        WebMock.should have_requested(method, url).once.with(headers: { 'Authorization' => 'Bearer aatoken' })
      end
    end

    it 'should use the access token if send_auth_headers is not set' do
      make_request_without_auth

      expected_calls.each do |method, url|
        WebMock.should have_requested(method, url).once.with(headers: { 'Authorization' => 'Bearer aatoken' })
      end
    end

    it 'should use the access token if send_auth_headers is set to a truthy value' do
      subject.send_auth_headers = 'wtf'

      make_request_without_auth

      expected_calls.each do |method, url|
        WebMock.should have_requested(method, url).once.with(headers: { 'Authorization' => 'Bearer aatoken' })
      end
    end

    with_access_token(:nil, :deleted) do
      it 'should raise AuthError if send_auth_headers is true' do
        subject.send_auth_headers = true

        expect { make_request_without_auth }.to raise_error(Minisky::AuthError)

        expected_calls.each { |method, url| WebMock.should_not have_requested(method, url) }
      end

      it 'should raise AuthError if send_auth_headers is not set' do
        expect { make_request_without_auth }.to raise_error(Minisky::AuthError)

        expected_calls.each { |method, url| WebMock.should_not have_requested(method, url) }
      end

      it 'should raise AuthError if send_auth_headers is set to a truthy value' do
        subject.send_auth_headers = 'wtf'

        expect { make_request_without_auth }.to raise_error(Minisky::AuthError)

        expected_calls.each { |method, url| WebMock.should_not have_requested(method, url) }
      end
    end

    with_access_token(:unchanged, :nil, :deleted) do
      it 'should not set the authorization header if send_auth_headers is false' do
        subject.send_auth_headers = false

        make_request_without_auth

        expected_calls.each do |method, url|
          WebMock.should have_requested(method, url).once
          WebMock.should_not have_requested(method, url).with(headers: { 'Authorization' => /.*/ })
        end
      end

      it 'should not set the authorization header if send_auth_headers is nil' do
        subject.send_auth_headers = nil

        make_request_without_auth

        expected_calls.each do |method, url|
          WebMock.should have_requested(method, url).once
          WebMock.should_not have_requested(method, url).with(headers: { 'Authorization' => /.*/ })
        end
      end
    end
  end
end
