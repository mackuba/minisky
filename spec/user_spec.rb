describe Minisky::User do
  let(:config) {{
    'id' => 'userid.bsky',
    'pass' => 'qwerty',
    'email' => 'admin@bsky.app'
  }}

  subject { Minisky::User.new(config) }

  it 'should pass missing methods to the config hash' do
    subject.id.should == 'userid.bsky'
    subject.pass.should == 'qwerty'
    subject.email.should == 'admin@bsky.app'
  end

  it 'should pass setters to the config hash' do
    subject.age = 33
    config['age'].should == 33
  end

  context '#logged_in?' do
    it 'should return false if access token is missing' do
      subject.logged_in?.should be false

      subject.instance_variable_get('@config')['refresh_token'] = 'rrrr'
      subject.logged_in?.should be false
    end

    it 'should return false if refresh token is missing' do
      subject.instance_variable_get('@config')['access_token'] = 'aaaa'
      subject.logged_in?.should be false
    end

    it 'should return true if both access token and refresh token are set' do
      subject.instance_variable_get('@config')['refresh_token'] = 'rrrr'
      subject.instance_variable_get('@config')['access_token'] = 'aaaa'
      subject.logged_in?.should be true
    end
  end

  context '#has_credentials?' do
    it 'should return false if id is missing' do
      subject.instance_variable_get('@config')['id'] = nil
      subject.has_credentials?.should be false
    end

    it 'should return false if pass is missing' do
      subject.instance_variable_get('@config')['pass'] = nil
      subject.has_credentials?.should be false
    end

    it 'should return true if both id and pass are set' do
      subject.has_credentials?.should be true
    end
  end
end