# Minisky 🌤

Minisky is a minimal client of the Bluesky (ATProto) API. It provides a simple API client class that you can use to log in to the Bluesky API and make any GET and POST requests there. It's meant to be an easy way to start playing and experimenting with the AT Protocol API.

This is designed as a low-level XRPC client library - it purposefully does not include any convenience methods like "get posts" or "get profile" etc., it only provides base components that you could use to build a higher level API.

> [!NOTE]
> Part of ATProto Ruby SDK: [ruby.sdk.blue](https://ruby.sdk.blue)


## Installation

To use Minisky, you need a reasonably new version of Ruby – it should run on Ruby 2.6 and above, although it's recommended to use a version that's still getting maintainance updates, i.e. currently 3.2+. A compatible version should be preinstalled on macOS Big Sur and above and on many Linux systems. Otherwise, you can install one using tools such as [RVM](https://rvm.io), [asdf](https://asdf-vm.com), [ruby-install](https://github.com/postmodern/ruby-install) or [ruby-build](https://github.com/rbenv/ruby-build), or `rpm` or `apt-get` on Linux (see more installation options on [ruby-lang.org](https://www.ruby-lang.org/en/downloads/)).

To install the Minisky gem, run the command:

    [sudo] gem install minisky

Or add it to your app's `Gemfile`:

    gem 'minisky', '~> 0.5'


## Usage

All calls to the XRPC API are made through an instance of the `Minisky` class. There are two ways to use the library: with or without authentication.


### Unauthenticated access

You can access parts of the API anonymously without any authentication. This currently includes: read-only `com.atproto.*` routes on the PDS (user's data server) and most read-only `app.bsky.*` routes on the AppView server.

This allows you to do things like:

- look up specific records or lists of all records of a given type in any account (in their raw form)
- look up profile information about any account
- load complete threads or users' profile feeds from the AppView

To use Minisky this way, create a `Minisky` instance, passing the API hostname string and `nil` as the configuration in the arguments. Use the hostname `api.bsky.app` or `public.api.bsky.app` for the AppView, or a PDS hostname for the `com.atproto.*` raw data endpoints:

```rb
require 'minisky'

bsky = Minisky.new('api.bsky.app', nil)
```

> [!NOTE]
> To call PDS endpoints like `getRecord` or `listRecords`, you need to connect to the PDS of the user whose data you're loading, not to yours (unless it's the same one). Alternatively, you can use the `bsky.social` "entryway" PDS hostname for any Bluesky-hosted accounts, but this will not work for self-hosted accounts.
>
> To look up the PDS hostname of a user given their handle or DID, you can use the [didkit](https://tangled.org/mackuba.eu/didkit) library.
>
> For the AppView, `api.bsky.app` connects directly to Bluesky's AppView, and `public.api.bsky.app` to a version with extra caching that will usually be faster.


### Authenticated access

To use the complete API including posting or reading your home feed, you need to log in using your account info and get an access token which will be added as an authentication header to all requests.

First, you need to create a `.yml` config file with the authentication data, e.g. `bluesky.yml`. It should look like this:

```yaml
id: my.bsky.username
pass: very-secret-password
```

The `id` can be either your handle, or your DID, or the email you've used to sign up. It's recommended that you use the "app password" that you can create in the settings instead of your main account password.

> [!NOTE]
> Bluesky has recently implemented OAuth, but Minisky doesn't support it yet - it will be added in a future version. App passwords should still be supported for a fairly long time.

After you log in, this file will also be used to store your access & request tokens and DID. The data in the config file can be accessed through a `user` wrapper property that exposes them as methods, e.g. the password is available as `user.pass` and the DID as `user.did`.

Next, create the Minisky client instance, passing your PDS hostname (for Bluesky-hosted PDSes, you can use either `bsky.social` or your specific PDS like `amanita.us-east.host.bsky.network`) and the name of the config file:

```rb
require 'minisky'

bsky = Minisky.new('bsky.social', 'bluesky.yml')
```

Minisky automatically manages your access and refresh tokens - it will first log you in using the login & password, and then use the refresh token to update the access token before the request when it expires.


### Making requests

With a `Minisky` client instance, you can make requests to the Bluesky API using `get_request` and `post_request`:

```rb
json = bsky.get_request('com.atproto.repo.listRecords', {
  repo: bsky.user.did,
  collection: 'app.bsky.feed.like'
})

json['records'].each do |r|
  puts r['value']['subject']['uri']
end

bsky.post_request('com.atproto.repo.createRecord', {
  repo: bsky.user.did,
  collection: 'app.bsky.feed.post',
  record: {
    text: "Hello world!",
    createdAt: Time.now.iso8601,
    langs: ["en"]
  }
})
```

In authenticated mode, the requests use the saved access token for auth headers automatically. You can also pass `auth: false` or `auth: nil` to not send any authentication headers for a given request, or `auth: sometoken` to use a specific other token. In unauthenticated mode, sending of auth headers is disabled.

The third useful method you can use is `#fetch_all`, which loads multiple paginated responses and collects all returned items on a single list (you need to pass the name of the field that contains the items in the response). Optionally, you can also specify a limit of pages to load as `max_pages: n`, or a break condition `break_when` to stop fetching when any item matches it. You can use it to e.g. to fetch all of your posts from the last 30 days but not earlier:

```rb
time_limit = Time.now - 86400 * 30

posts = bsky.fetch_all('com.atproto.repo.listRecords',
  { repo: bsky.user.did, collection: 'app.bsky.feed.post' },
  field: 'records',
  max_pages: 10,
  break_when: ->(x) { Time.parse(x['value']['createdAt']) < time_limit })
```

There is also a `progress` option you can use to print some kind of character for every page load. E.g. pass `progress: '.'` to print dots as the pages are loading:

```rb
likes = bsky.fetch_all('com.atproto.repo.listRecords',
  { repo: bsky.user.did, collection: 'app.bsky.feed.like' },
  field: 'records',
  progress: '.')
```

This will output a line like this:

```
.................
```

You can find more examples on the [examples page](https://ruby.sdk.blue/examples/) on [ruby.sdk.blue](https://ruby.sdk.blue).


## Customization

The `Minisky` client currently supports such configuration options:

- `default_progress` - a progress character to automatically use for `#fetch_all` calls (default: `.` when in an interactive console, `nil` otherwise)
- `send_auth_headers` - whether auth headers should be added by default (default: `true` in authenticated mode)
- `auto_manage_tokens` - whether access tokens should be generated and refreshed automatically when needed (default: `true` in authenticated mode)

In authenticated mode, you can disable the `send_auth_headers` option and then explicitly add `auth: true` to specific requests to include a header there.

You can also disable the `auto_manage_tokens` option - in this case you will need to call the `#check_access` method before a request to refresh a token if needed, or alternatively, call either `#login` or `#perform_token_refresh`.


### Using your own class

Instead of using the `Minisky` class, you can also make your own class that includes the `Minisky::Requests` module and provides a different way to load & save the config, e.g. from a JSON file:

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
bsky.get_request(...)
```

The class needs to provide:

- a `host` method or property that returns the hostname of the server
- a `config` property which returns a hash or a hash-like object with the configuration and user data - it needs to support reading and writing arbitrary key-value pairs with string keys
- a `save_config` method which persists the config object to the chosen storage


## Credits

Copyright © 2026 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
