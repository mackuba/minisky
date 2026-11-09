require_relative 'ex_requests_with_auth'

shared_examples "fetch_all" do |include_auth_tests:|
  describe '#fetch_all' do
    context 'when one page of items is returned' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "items": ["one", "two", "three"] }
        ])
      end

      it 'should make one request to the given endpoint' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items')
        verify_fetch_all
      end

      it 'should return the parsed items' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items')
        result.should == ["one", "two", "three"]
      end
    end

    context 'when more than one page of items is returned' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "items": ["one", "two", "three"] },
          { "items": ["four", "five"] },
        ])
      end

      it 'should make multiple requests, passing the cursor from the previous page' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items')
        verify_fetch_all
      end

      it 'should return all the parsed items collected from the responses' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items')
        result.should == ["one", "two", "three", "four", "five"]
      end
    end

    context 'if one of the pages returns an error response' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return_json(body: { "items": ["one", "two", "three"], "cursor": "c7" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=c7")
          .to_return(
            body: JSON.generate(error: 'Server error', message: 'Something went very wrong'),
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          )
      end

      it 'should rethrow the error from the last page fetch' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: 'items') }.to raise_error { |err|
          err.should be_a(Minisky::ServerErrorResponse)
          err.status.should == 500
          err.data.should be_a(Hash)
          err.error_type.should == 'Server error'
          err.error_message.should == 'Something went very wrong'
        }

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=c7").once
      end
    end

    context 'if the response includes a cursor set to explicit null' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return_json(body: { "items": ["one", "two", "three"], "cursor": "c7" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=c7")
          .to_return_json(body: { "items": ["four", "five"], "cursor": nil })
      end

      it 'should accept the response and stop at that page' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items')

        result.should == ["one", "two", "three", "four", "five"]

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=c7").once
      end
    end

    context 'when params are passed' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll?type=post", [
          { "items": ["one", "two", "three"] },
          { "items": ["four", "five"] },
        ])
      end

      it 'should add the params to the url' do
        subject.fetch_all('com.example.service.fetchAll', { type: 'post' }, field: 'items')
        verify_fetch_all
      end

      it 'should not modify passed params object in place' do
        params = { type: 'post' }.freeze

        subject.fetch_all('com.example.service.fetchAll', params, field: 'items')
      end
    end

    context 'when params are empty' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "items": ["one", "two", "three"] },
          { "items": ["four", "five"] },
        ])
      end

      it 'should not add anything to the url' do
        subject.fetch_all('com.example.service.fetchAll', {}, field: 'items')
        verify_fetch_all
      end
    end

    context 'when params are an explicit nil' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "items": ["one", "two", "three"] },
          { "items": ["four", "five"] },
        ])
      end

      it 'should not add anything to the url' do
        subject.fetch_all('com.example.service.fetchAll', nil, field: 'items')
        verify_fetch_all
      end
    end

    context 'when headers are passed' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "items": ["one", "two", "three"] },
          { "items": ["four", "five"] },
        ])
      end

      let(:headers) {{ 'X-API-Key' => 'waow' }}

      it 'should pass the headers to every request' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items', headers: headers)

        @stubbed_urls.each do |url|
          WebMock.should have_requested(:get, url).once.with(headers: headers)
        end
      end
    end

    context 'if the method name is a URL string' do
      it 'should request that URL' do
        stub_fetch_all("https://other.host/xrpc/com.atproto.repo.listRecords", [
          { "records": [{ a: 1 }, { a: 5 }] },
          { "records": [{ b: 7 }] },
        ])

        subject.fetch_all('https://other.host/xrpc/com.atproto.repo.listRecords', field: 'records')

        verify_fetch_all
      end
    end

    context 'if the method name is a URI object' do
      it 'should request that URI' do
        stub_fetch_all("https://other.host/xrpc/com.atproto.repo.listRecords", [
          { "records": [{ a: 1 }, { a: 5 }] },
          { "records": [{ b: 7 }] },
        ])

        subject.fetch_all(URI('https://other.host/xrpc/com.atproto.repo.listRecords'), field: 'records')

        verify_fetch_all
      end
    end

    describe '…' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return_json(body: { "items": ["one", "two", "three"], "cursor": "ccc333" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333")
          .to_return_json(body: { "items": ["four", "five"] })
      end

      if include_auth_tests
        include_examples "requests with authentication",
          request: ->(subject, params) {
            subject.fetch_all('com.example.service.fetchAll', field: 'items', **params)
          },
          expected: ->(host) {[
            [:get, "https://#{host}/xrpc/com.example.service.fetchAll"],
            [:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333"]
          ]}
      end
    end

    context 'when break condition is passed' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "items": ["one", "two", "three"] },
          { "items": ["four", "five"] },
          { "items": ["six"] },
        ])
      end

      it 'should stop when a matching item is found' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items', break_when: ->(x) { x =~ /u/ })

        WebMock.should have_requested(:get, @stubbed_urls[0]).once
        WebMock.should have_requested(:get, @stubbed_urls[1]).once
        WebMock.should_not have_requested(:get, @stubbed_urls[2])
      end

      it 'should filter out matching items from the response' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items', break_when: ->(x) { x =~ /u/ })
        result.should == ["one", "two", "three", "five"]
      end
    end

    context 'when max pages limit is passed' do
      before do
        stub_request(:get, %r(https://#{host}/xrpc/com.example.service.fetchAll(\?.*)?))
          .to_return_json(
            body: ->(req) {
              params = req.uri.query_values || {}
              page = params['cursor'].to_s.gsub(/page/, '').to_i
              { items: ["item#{page}"], cursor: "page#{page + 1}" }
            }
          )
      end

      context 'and break_when is not passed' do
        it 'should stop at n-th page' do
          subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 5)

          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page3").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page4").once
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page5")
        end

        it 'should collect all items' do
          result = subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 5)
          result.should == ["item0", "item1", "item2", "item3", "item4"]
        end
      end

      context 'and break_when matches earlier' do
        it 'should stop at the page where break_when matches' do
          subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 5,
            break_when: ->(x) { x =~ /3/ })

          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page3").once
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page4")
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page5")
        end

        it 'should exclude items that matched break_when' do
          result = subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 5,
            break_when: ->(x) { x =~ /3/ })

          result.should == ["item0", "item1", "item2"]
        end
      end

      context "and break_when doesn't match earlier" do
        it 'should stop at the n-th page' do
          subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 6,
            break_when: ->(x) { x =~ /8/ })

          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page3").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page4").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page5").once
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page6")
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page7")
        end

        it 'should include all items up to n-th page' do
          result = subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 6,
            break_when: ->(x) { x =~ /8/ })

          result.should == ["item0", "item1", "item2", "item3", "item4", "item5"]
        end
      end

      context "and break_when matches on the last page" do
        it 'should stop at the n-th page' do
          subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 6,
            break_when: ->(x) { x =~ /5/ })

          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page3").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page4").once
          WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page5").once
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page6")
          WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page7")
        end

        it 'should exclude the items matching on the last page' do
          result = subject.fetch_all('com.example.service.fetchAll', field: 'items', max_pages: 6,
            break_when: ->(x) { x =~ /5/ })

          result.should == ["item0", "item1", "item2", "item3", "item4"]
        end
      end

      it 'should throw an error if max_pages is 0' do
        expect { subject.fetch_all('app.bsky.feed.getPosts', field: 'feed', max_pages: 0) }.to raise_error(
          ArgumentError, "max_pages should be a positive integer"
        )
      end

      it 'should throw an error if max_pages is negative' do
        expect { subject.fetch_all('app.bsky.feed.getPosts', field: 'feed', max_pages: -2) }.to raise_error(
          ArgumentError, "max_pages should be a positive integer"
        )
      end

      it 'should throw an error if max_pages is a float' do
        expect { subject.fetch_all('app.bsky.feed.getPosts', field: 'feed', max_pages: 1.5) }.to raise_error(
          ArgumentError, "max_pages should be a positive integer"
        )
      end

      it 'should throw an error if max_pages is not a number' do
        expect { subject.fetch_all('app.bsky.feed.getPosts', field: 'feed', max_pages: 'max') }.to raise_error(
          ArgumentError, "max_pages should be a positive integer"
        )
      end
    end

    context 'when an empty page is received, but with a cursor' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "feed": ["one", "two", "three"] },
          { "feed": [] },
          { "feed": ["six"] },
        ])
      end

      it 'should continue fetching until the cursor is nil' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'feed')
        result.should == ['one', 'two', 'three', 'six']
      end

      context 'with stop_fetch_on_empty_page option set to true' do
        before do
          subject.stop_fetch_on_empty_page = true
        end

        it 'should stop at the first empty page' do
          result = subject.fetch_all('com.example.service.fetchAll', field: 'feed')
          result.should == ['one', 'two', 'three']

          WebMock.should have_requested(:get, @stubbed_urls[0]).once
          WebMock.should have_requested(:get, @stubbed_urls[1]).once
          WebMock.should_not have_requested(:get, @stubbed_urls[2])
        end
      end
    end

    context 'when a cursor is received that have already been seen on an earlier page' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return_json(body: { "items": ["one", "two", "three"], "cursor": "cursorX" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=cursorX")
          .to_return_json(body: { "items": ["four", "five"], "cursor": "cursorY" })
          .then.to_raise(StandardError.new('Infinite request loop'))

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=cursorY")
          .to_return_json(body: { "items": ["four", "five"], "cursor": "cursorX" })
      end

      it 'should throw an InvalidCursorError' do
        expect {
          subject.fetch_all('com.example.service.fetchAll', field: 'items')
        }.to raise_error(Minisky::InvalidCursorError)

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=cursorX").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=cursorY").once
      end
    end

    context 'when field is not passed' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "thingies": ["one", "two", "three"], "best": "two", "foobars": ["foo", "bar"], "total": 6 },
          { "items": ["four", "five"] },
        ])
      end

      it 'should make one request and raise an error with list of array fields' do
        expect { subject.fetch_all('com.example.service.fetchAll') }.to raise_error { |err|
          err.should be_a(Minisky::FieldNotSetError)
          err.fields.should == ['thingies', 'foobars']
        }

        WebMock.should have_requested(:get, @stubbed_urls[0]).once
        WebMock.should_not have_requested(:get, @stubbed_urls[1])
      end
    end

    context 'when field is nil' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "thingies": ["one", "two", "three"], "best": "two", "foobars": ["foo", "bar"], "total": 6 },
          { "items": ["four", "five"] },
        ])
      end

      it 'should make one request and raise an error with list of array fields' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: nil) }.to raise_error { |err|
          err.should be_a(Minisky::FieldNotSetError)
          err.fields.should == ['thingies', 'foobars']
        }

        WebMock.should have_requested(:get, @stubbed_urls[0]).once
        WebMock.should_not have_requested(:get, @stubbed_urls[1])
      end
    end

    context 'when a response object is not a hash' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "thingies": ["one", "two", "three"], "best": "two", "foobars": ["foo", "bar"], "total": 6 },
          ["four", "five"],
        ])
      end

      it 'should raise an error' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: 'thingies') }.to raise_error(
          Minisky::InvalidJSONError, /Received response is not in expected JSON format/
        )

        verify_fetch_all
      end
    end

    context 'when a response object does not contain the expected records field' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "thingies": ["one", "two", "three"], "best": "two", "foobars": ["foo", "bar"], "total": 6 },
          { "items": ["four", "five"] },
        ])
      end

      it 'should raise an error' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: 'thingies') }.to raise_error(
          Minisky::InvalidJSONError, /No such field in the response JSON: 'thingies'/
        )

        verify_fetch_all
      end
    end

    context 'when the expected records field has nil value' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "thingies": ["one", "two", "three"], "best": "two", "foobars": ["foo", "bar"], "total": 6 },
          { "thingies": nil, "items": ["four", "five"] },
        ])
      end

      it 'should raise an error' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: 'thingies') }.to raise_error(
          Minisky::InvalidJSONError, /Field 'thingies' is nil in the received response/
        )

        verify_fetch_all
      end
    end

    context 'when the expected records field is not an array' do
      before do
        stub_fetch_all("https://#{host}/xrpc/com.example.service.fetchAll", [
          { "thingies": ["one", "two", "three"], "best": "two", "foobars": ["foo", "bar"], "total": 6 },
          { "thingies": { "items": ["four", "five"] }},
        ])
      end

      it 'should raise an error' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: 'thingies') }.to raise_error(
          Minisky::InvalidJSONError, /Invalid 'thingies': expected Array, got Hash/
        )

        verify_fetch_all
      end
    end

    context 'when field is nil and the response is not a hash' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: "string response", headers: { 'Content-Type' => 'text/plain' })
      end

      it 'should raise a InvalidJSONError error' do
        expect { subject.fetch_all('com.example.service.fetchAll', field: nil) }.to raise_error(
          Minisky::InvalidJSONError, /Received response is not in expected JSON format/
        )
      end
    end

    describe 'progress param' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return_json(body: { "items": ["one"], "cursor": "page1" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1")
          .to_return_json(body: { "items": ["two"], "cursor": "page2" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2")
          .to_return_json(body: { "items": ["three"] })
      end

      context 'when it is passed' do
        it 'should print the progress character for each request' do
          expect {
            subject.fetch_all('com.example.service.fetchAll', field: 'items', progress: '-=')
          }.to output('-=-=-=').to_stdout
        end
      end

      context 'when it is not passed' do
        it 'should not print anything' do
          expect {
            subject.fetch_all('com.example.service.fetchAll', field: 'items')
          }.to output('').to_stdout
        end
      end

      context 'when it is passed and a default is set' do
        it 'should use the param version' do
          subject.default_progress = '@'

          expect {
            subject.fetch_all('com.example.service.fetchAll', field: 'items', progress: '#')
          }.to output('###').to_stdout
        end
      end

      context 'when it is not passed and a default is set' do
        it 'should use the default version' do
          subject.default_progress = '$'

          expect {
            subject.fetch_all('com.example.service.fetchAll', field: 'items')
          }.to output('$$$').to_stdout
        end
      end

      context 'when default is set and nil is passed' do
        it 'should not output anything' do
          subject.default_progress = '$'

          expect {
            subject.fetch_all('com.example.service.fetchAll', field: 'items', progress: nil)
          }.to output('').to_stdout
        end
      end

      context 'when default is set and false is passed' do
        it 'should not output anything' do
          subject.default_progress = '$'

          expect {
            subject.fetch_all('com.example.service.fetchAll', field: 'items', progress: false)
          }.to output('').to_stdout
        end
      end
    end
  end

  context 'if a timeout option is set on the client instance' do
    it 'should pass that timeout to Net::HTTP for each page' do
      subject.timeout = 23

      responses = [
        { items: ['one'], cursor: 'page2' },
        { items: ['two'] }
      ].map do |body|
        response = Net::HTTPOK.new('1.1', '200', 'OK')
        response['Content-Type'] = 'application/json'
        response.stubs(:body).returns(JSON.generate(body))
        response
      end

      Net::HTTP.expects(:start)
          .with(host, 443, { use_ssl: true, open_timeout: 23, read_timeout: 23 })
          .twice
          .returns(*responses)

      subject.fetch_all('com.example.service.fetchAll', field: 'items').should == ['one', 'two']
    end
  end
end
