require 'yaml'

describe Minisky do
  include FakeFS::SpecHelpers

  before do
    File.write('bluesky.yml', %(
      ident: john.foo
      pass: hunter2
      access_token: aatoken
      refresh_token: rrtoken
    ))
  end

  subject { Minisky.new(host) }

  let(:reloaded_config) { YAML.load(File.read('bluesky.yml')) }

  it 'should have a version number' do
    Minisky::VERSION.should_not be_nil
  end

  include_examples "Requests", 'bsky.test'
end
