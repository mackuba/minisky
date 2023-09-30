shared_examples 'authorization' do |http_method, endpoint_name|
  let(:method_name) { "#{http_method}_request" }
  let(:url) { "https://#{host}/xrpc/#{endpoint_name}" }

  [true, false, nil, :undefined, 'wtf'].each do |v|
    context "with send_auth_headers set to #{v.inspect}" do
      before do
        subject.send_auth_headers = v unless v == :undefined
      end

      context 'with an explicit auth token' do
        it 'should pass the token in the header' do
          subject.send(method_name, endpoint_name, auth: 'qwerty99')

          WebMock.should have_requested(http_method, url).once
            .with(headers: { 'Authorization' => 'Bearer qwerty99' })
        end
      end

      context 'with auth = true' do
        it 'should use the access token' do
          subject.send(method_name, endpoint_name, auth: true)

          WebMock.should have_requested(http_method, url).once
            .with(headers: { 'Authorization' => 'Bearer aatoken' })
        end
      end

      context 'with auth = false' do
        it 'should not set the authorization header' do
          subject.send(method_name, endpoint_name, auth: false)

          WebMock.should have_requested(http_method, url).once
          WebMock.should_not have_requested(http_method, url)
            .with(headers: { 'Authorization' => /.*/ })
        end
      end

      context 'with auth = nil' do
        it 'should not set the authorization header' do
          subject.send(method_name, endpoint_name, auth: nil)

          WebMock.should have_requested(http_method, url).once
          WebMock.should_not have_requested(http_method, url)
            .with(headers: { 'Authorization' => /.*/ })
        end
      end
    end
  end

  context 'without an auth parameter' do
    it 'should use the access token if send_auth_headers is true' do
      subject.send_auth_headers = true
      subject.send(method_name, endpoint_name)

      WebMock.should have_requested(http_method, url).once
        .with(headers: { 'Authorization' => 'Bearer aatoken' })
    end

    it 'should use the access token if send_auth_headers is not set' do
      subject.send(method_name, endpoint_name)

      WebMock.should have_requested(http_method, url).once
        .with(headers: { 'Authorization' => 'Bearer aatoken' })
    end

    it 'should use the access token if send_auth_headers is set to a truthy value' do
      subject.send_auth_headers = 'wtf'
      subject.send(method_name, endpoint_name)

      WebMock.should have_requested(http_method, url).once
        .with(headers: { 'Authorization' => 'Bearer aatoken' })
    end

    it 'should not set the authorization header if send_auth_headers is false' do
      subject.send_auth_headers = false
      subject.send(method_name, endpoint_name)

      WebMock.should have_requested(http_method, url).once
      WebMock.should_not have_requested(http_method, url)
        .with(headers: { 'Authorization' => /.*/ })
    end

    it 'should not set the authorization header if send_auth_headers is nil' do
      subject.send_auth_headers = nil
      subject.send(method_name, endpoint_name)

      WebMock.should have_requested(http_method, url).once
      WebMock.should_not have_requested(http_method, url)
        .with(headers: { 'Authorization' => /.*/ })
    end
  end
end
