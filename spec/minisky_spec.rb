require 'yaml'

describe Minisky do
  include FakeFS::SpecHelpers

  let(:host) { 'bsky.test' }

  before do
    File.write('myconfig.yml', %(
      id: john.foo
      pass: hunter2
      access_token: aatoken
      refresh_token: rrtoken
    ))
  end

  subject { Minisky.new(host, 'myconfig.yml') }

  let(:reloaded_config) { YAML.load(File.read('myconfig.yml')) }

  it 'should have a version number' do
    Minisky::VERSION.should_not be_nil
  end

  include_examples "Requests", 'bsky.test'
end
