require_relative 'ex_authorization'
require_relative 'ex_bad_response'

shared_examples "get_request" do
  describe '#get_request' do
    before do
      stub_request(:get, %r(https://#{host}/xrpc/com.example.service.getStuff(\?.*)?)).to_return(response)
    end

    let(:response) {{ body: JSON.generate({ "result": 123 }), headers: { content_type: 'application/json' }}}

    it 'should make a request to the given XRPC endpoint' do
      subject.get_request('com.example.service.getStuff')

      WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
    end

    it 'should return parsed JSON' do
      result = subject.get_request('com.example.service.getStuff')

      result.should == { 'result' => 123 }
    end

    context 'with params' do
      it 'should append params to the URL' do
        subject.get_request('com.example.service.getStuff', { repo: 'whitehouse.gov', limit: 80 })

        WebMock.should have_requested(:get,
         "https://#{host}/xrpc/com.example.service.getStuff?repo=whitehouse.gov&limit=80").once
      end
    end

    context 'with nil params' do
      it 'should not append anything to the URL' do
        subject.get_request('com.example.service.getStuff', nil)

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
      end
    end

    context 'with empty params' do
      it 'should not append anything to the URL' do
        subject.get_request('com.example.service.getStuff', {})

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff").once
      end
    end

    context 'with an array passed as param' do
      it 'should append one copy of the param for each item' do
        subject.get_request('com.example.service.getStuff', { profiles: ['john.foo', 'spam.zip'], reposts: true })

        WebMock.should have_requested(:get,
         "https://#{host}/xrpc/com.example.service.getStuff?profiles=john.foo&profiles=spam.zip&reposts=true").once
      end
    end

    context 'with headers' do
      it 'should include the custom headers' do
        subject.get_request('com.example.service.getStuff', { user: 'alf.gov' }, headers: { 'Food': 'cats' })

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.getStuff?user=alf.gov").once
         .with(headers: { 'Food' => 'cats' })
      end
    end

    context 'with an invalid method name' do
      it 'should raise an ArgumentError' do
        INVALID_METHOD_NAMES.each do |m|
          expect { subject.get_request(m) }.to raise_error(ArgumentError)
        end
      end
    end

    include_examples "bad response handling", :get, 'com.example.service.getStuff'

    include_examples "authorization",
      request: ->(subject, params) { subject.get_request('com.example.service.getStuff', **params) },
      expected: ->(host) { [:get, "https://#{host}/xrpc/com.example.service.getStuff"] }
  end
end
