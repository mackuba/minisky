shared_examples "fetch_all" do
  describe '#fetch_all' do
    context 'when one page of items is returned' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: '{ "items": ["one", "two", "three"] }')
      end

      it 'should make one request to the given endpoint' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
      end

      it 'should return the parsed items' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items')
        result.should == ["one", "two", "three"]
      end
    end

    context 'when more than one page of items is returned' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: '{ "items": ["one", "two", "three"], "cursor": "ccc111" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc111")
          .to_return(body: '{ "items": ["four", "five"] }')
      end

      it 'should make multiple requests, passing the last cursor' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc111").once
      end

      it 'should return all the parsed items collected from the responses' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items')
        result.should == ["one", "two", "three", "four", "five"]
      end
    end

    context 'when params are passed' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?type=post")
          .to_return(body: '{ "items": ["one", "two", "three"], "cursor": "ccc222" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?type=post&cursor=ccc222")
          .to_return(body: '{ "items": ["four", "five"] }')
      end

      it 'should add the params to the url' do
        subject.fetch_all('com.example.service.fetchAll', { type: 'post' }, field: 'items')

        WebMock.should have_requested(:get,
          "https://#{host}/xrpc/com.example.service.fetchAll?type=post").once
        WebMock.should have_requested(:get,
          "https://#{host}/xrpc/com.example.service.fetchAll?type=post&cursor=ccc222").once
      end
    end

    context 'when params are an explicit nil' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: '{ "items": ["one", "two", "three"], "cursor": "ccc222" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc222")
          .to_return(body: '{ "items": ["four", "five"] }')
      end

      it 'should not add anything to the url' do
        subject.fetch_all('com.example.service.fetchAll', nil, field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc222").once
      end
    end

    [true, false, nil, :undefined, 'wtf'].each do |v|
      context "with send_auth_headers set to #{v.inspect}" do
        before do
          stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
            .to_return(body: '{ "items": ["one", "two", "three"], "cursor": "ccc333" }')

          stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333")
            .to_return(body: '{ "items": ["four", "five"] }')

          subject.send_auth_headers = v unless v == :undefined
        end

        context 'with an explicit token' do
          it 'should pass the token in the header' do
            subject.fetch_all('com.example.service.fetchAll', auth: 'XXXX', field: 'items')

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
              .with(headers: { 'Authorization' => 'Bearer XXXX' })
            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
              .with(headers: { 'Authorization' => 'Bearer XXXX' })
          end
        end

        context 'with auth = false' do
          it 'should not add an authentication header' do
            subject.fetch_all('com.example.service.fetchAll', field: 'items', auth: false)

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
            WebMock.should_not have_requested(:get, %r(https://#{host}/xrpc/com.example.service.fetchAll))
              .with(headers: { 'Authorization' => /.*/ })
          end
        end

        context 'with auth = nil' do
          it 'should not add an authentication header' do
            subject.fetch_all('com.example.service.fetchAll', field: 'items', auth: nil)

            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
            WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
            WebMock.should_not have_requested(:get, %r(https://#{host}/xrpc/com.example.service.fetchAll))
              .with(headers: { 'Authorization' => /.*/ })
          end
        end
      end
    end

    context "without an auth parameter" do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: '{ "items": ["one", "two", "three"], "cursor": "ccc333" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333")
          .to_return(body: '{ "items": ["four", "five"] }')
      end

      it 'should use the access token if send_auth_headers is true' do
        subject.send_auth_headers = true
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should use the access token if send_auth_headers is not set' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should use the access token if send_auth_headers is set to a truthy value' do
        subject.send_auth_headers = 'wtf'
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
          .with(headers: { 'Authorization' => 'Bearer aatoken' })
      end

      it 'should not add an authentication header if send_auth_headers is false' do
        subject.send_auth_headers = false
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
        WebMock.should_not have_requested(:get, %r(https://#{host}/xrpc/com.example.service.fetchAll))
          .with(headers: { 'Authorization' => /.*/ })
      end

      it 'should not add an authentication header if send_auth_headers is nil' do
        subject.send_auth_headers = nil
        subject.fetch_all('com.example.service.fetchAll', field: 'items')

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333").once
        WebMock.should_not have_requested(:get, %r(https://#{host}/xrpc/com.example.service.fetchAll))
          .with(headers: { 'Authorization' => /.*/ })
      end
    end

    context 'when break condition is passed' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: '{ "items": ["one", "two", "three"], "cursor": "page1" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1")
          .to_return(body: '{ "items": ["four", "five"], "cursor": "page2" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2")
          .to_return(body: '{ "items": ["six"] }')
      end

      it 'should stop when a matching item is found' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items', break_when: ->(x) { x =~ /u/ })

        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll").once
        WebMock.should have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1").once
        WebMock.should_not have_requested(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2")
      end

      it 'should filter out matching items from the response' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items', break_when: ->(x) { x =~ /u/ })
        result.should == ["one", "two", "three", "five"]
      end
    end

    context 'when max pages limit is passed' do
      before do
        stub_request(:get, %r(https://#{host}/xrpc/com.example.service.fetchAll(\?.*)?))
          .to_return { |req|
            params = req.uri.query_values || {}
            page = params['cursor'].to_s.gsub(/page/, '').to_i
            { body: JSON.generate({ items: ["item#{page}"], cursor: "page#{page + 1}" }) }
          }
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
    end

    describe 'progress param' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return(body: '{ "items": ["one"], "cursor": "page1" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page1")
          .to_return(body: '{ "items": ["two"], "cursor": "page2" }')

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=page2")
          .to_return(body: '{ "items": ["three"] }')
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
end
