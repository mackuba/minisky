shared_examples "custom client with incomplete auth" do
  it 'should have send_auth_headers enabled' do
    subject.send_auth_headers.should == true
  end

  it 'should have auto_manage_tokens enabled' do
    subject.auto_manage_tokens.should == true
  end

  it 'should fail on get_request' do
    expect { subject.get_request('com.example.service.getStuff') }.to raise_error(Minisky::AuthError)
  end

  it 'should fail on post_request' do
    expect { subject.post_request('com.example.service.doStuff', 'qqq') }.to raise_error(Minisky::AuthError)
  end

  it 'should fail on fetch_all' do
    expect { subject.fetch_all('com.example.service.fetchStuff', {}, field: 'feed') }.to raise_error(Minisky::AuthError)
  end

  it 'should fail on check_access' do
    expect { subject.check_access }.to raise_error(Minisky::AuthError)
  end

  it 'should fail on log_in' do
    expect { subject.log_in }.to raise_error(Minisky::AuthError)
  end

  it 'should fail on perform_token_refresh' do
    expect { subject.perform_token_refresh }.to raise_error(Minisky::AuthError)
  end

  # todo perform w/ access token
  # todo test if properties turned off
end
