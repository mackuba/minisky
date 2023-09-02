# Minisky

Minisky is a minimal client of the Bluesky (ATProto) API. It provides a simple API client class that you can use to log in to the Bluesky API and make any GET and POST requests there. It's meant to be an easy way to start playing and experimenting with the AT Protocol API.


## Installation

To use Minisky, you need a reasonably new version of Ruby (2.6+). Such version should be preinstalled on macOS Big Sur and above and some Linux systems. Otherwise, you can install one using tools such as [RVM](https://rvm.io), [asdf](https://asdf-vm.com), [ruby-install](https://github.com/postmodern/ruby-install) or [ruby-build](https://github.com/rbenv/ruby-build), or `rpm` or `apt-get` on Linux.

To install the Minisky gem, run the command:

    [sudo] gem install minisky

Or alternatively, add it to the `Gemfile` file for Bundler:

    gem 'minisky', '~> 0.2'


## Usage

First, you need to create a `.yml` config file (by default, `bluesky.yml`) with the authentication data. It should look like this:

```yaml
id: my.bsky.username
pass: very-secret-password
```

The `id` can be either your handle, or your DID, or the email you've used to sign up. It's recommended that you use the "app password" that you can create in the settings instead of your main account password.

After you log in, this file will also be used to store your access & request tokens and DID. The data in the config file can be accessed through a `user` wrapper property that exposes them as methods, e.g. the password is available as `user.pass` and the DID as `user.did`.

Next, create the Minisky client instance, passing the server name (at the moment there is only one server at `bsky.social`, but there will be more once federation support goes live):

```rb
require 'minisky'

bsky = Minisky.new('bsky.social')
bsky.check_access
```

`check_access` will check if an access token is saved, if not - it will log you in using the login & password, otherwise it will check if the token is still valid and refresh it if needed.

Now, you can make requests to the Bluesky API using `get_request` and `post_request`:

```rb
bsky.get_request('com.atproto.repo.listRecords', {
  repo: bsky.user.did,
  collection: 'app.bsky.feed.like'
})

bsky.post_request('com.atproto.repo.createRecord', {
  repo: bsky.user.did,
  collection: 'app.bsky.feed.post',
  record: {
    text: "Hello world!",
    createdAt: Time.now.iso8601
  }
})
```

The requests use the saved access token for authentication automatically. You can also pass `auth: false` or `auth: nil` to not send any authentication headers, or `auth: sometoken` to use a specific other token.

The third useful method you can use is `#fetch_all`, which loads multiple paginated responses and collects all returned items on a single list (you need to pass the name of the field that contains the items in the response). Optionally, you can also specify a limit of pages to load as `max_pages: n`, or a break condition `break_when` to stop fetching when any item matches it. You can use it to e.g. to fetch all of your posts from the last 30 days, but not earlier:

```rb
time_limit = Time.now - 86400 * 30

bsky.fetch_all('com.atproto.repo.listRecords',
  { repo: bsky.user.did, collection: 'app.bsky.feed.post' },
  field: 'records',
  max_pages: 10,
  break_when: ->(x) { Time.parse(x['value']['createdAt']) < time_limit })
```

There is also a `progress` option you can use to print some kind of character for every page load. E.g. pass `progress: '.'` to print dots as the pages are loading:

```rb
bsky.fetch_all('com.atproto.repo.listRecords',
  { repo: bsky.user.did, collection: 'app.bsky.feed.like' },
  field: 'records',
  progress: '.')
```

This will output a line like this:

```
.................
```

## Customization

The `Minisky` client currently supports one configuration option:

- `default_progress` - a progress character to automatically use for `#fetch_all` calls (default: `nil`)

When creating the `Minisky` instance, you can pass a name of the YAML config file to use instead of the default:

```rb
bsky = Minisky.new('bsky.social', 'config/access.yml')
```

Alternatively, instead of using the `Minisky` class, you can make your own class that includes the `Minisky::Requests` module and provides a different way to load & save the config, e.g. from a JSON file:

```rb
class BlueskyClient
  include Minisky::Requests

  attr_reader :config

  def initialize(config_file)
    @config_file = config_file
    @config = JSON.parse(File.read(@config_file))
  end

  def host
    'bsky.social'
  end

  def save_config
    File.write(@config_file, JSON.pretty_generate(@config))
  end
end
```

It can then be used just like the `Minisky` class:

```rb
bsky = BlueskyClient.new('config/access.json')
bsky.check_access
bsky.get_request(...)
```

The class needs to provide:

- a `host` method or property that returns the hostname of the server
- a `config` property which returns a hash or a hash-like object with the configuration and user data - it needs to support reading and writing arbitrary key-value pairs with string keys
- a `save_config` method which persists the config object to the chosen storage


## Credits

Copyright © 2023 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/mackuba.eu)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
