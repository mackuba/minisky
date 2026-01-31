shared_examples "fetch_all" do
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

      it 'should make multiple requests, passing the last cursor' do
        subject.fetch_all('com.example.service.fetchAll', field: 'items')
        verify_fetch_all
      end

      it 'should return all the parsed items collected from the responses' do
        result = subject.fetch_all('com.example.service.fetchAll', field: 'items')
        result.should == ["one", "two", "three", "four", "five"]
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

    describe '…' do
      before do
        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll")
          .to_return_json(body: { "items": ["one", "two", "three"], "cursor": "ccc333" })

        stub_request(:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333")
          .to_return_json(body: { "items": ["four", "five"] })
      end

      include_examples "authorization",
        request: ->(subject, params) {
          subject.fetch_all('com.example.service.fetchAll', field: 'items', **params)
        },
        expected: ->(host) {[
          [:get, "https://#{host}/xrpc/com.example.service.fetchAll"],
          [:get, "https://#{host}/xrpc/com.example.service.fetchAll?cursor=ccc333"]
        ]}
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
end
