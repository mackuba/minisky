## Unreleased

* don't stop fetching in `fetch_all` if an empty page is returned but the cursor is not nil; it's technically allowed for the server to return an empty page but still have more data to send
* in `post_request`, don't set Content-Type to "application/json" if the data sent is a string or nil (it might cause an error in some cases)
* allow connecting to non-HTTPS servers (e.g. `http://localhost:3000`)
* deprecate logging in using an email address in the `id` field – `createSession` accepts such identifier, but unlike with handle or DID, there's no way to use it to look up the DID document and PDS location if we wanted to
* marked `Minisky#active_repl?` method as private

## [0.5.0] - 2024-12-27 🎄

* `host` param in the initializer can be passed with a `https://` prefix (useful if you're passing it directly from a DID document, e.g. using DIDKit)
* added validation of the `method` parameter in request calls: it needs to be either a proper NSID, or a full URL as a string or a URI object
* added new optional `params` keyword argument in `post_request`, which lets you append query parameters to the URL if a POST endpoint requires passing them this way
* `default_progress` is set by default to show progress using dots (`.`) if Minisky is loaded inside an IRB or Pry context
* when experimenting with Minisky in the console, you can now skip the `field:` parameter to `fetch_all` if you don't remember the expected key name in the response, and the method will make a request and return an error which tells you the list of available keys
* added `access_token_expired?` helper method
* moved `token_expiration_date` to public methods
* `check_access` now returns a result symbol: `:logged_in`, `:refreshed` or `:ok`
* fixed `method_missing` setter on `User`

## [0.4.0] - 2024-03-31 🐣

* allow passing non-JSON body to requests (e.g. when uploading blobs)
* allow passing custom headers to requests, including overriding `Content-Type`
* fixed error when the response is success but not JSON (e.g. an empty body like in deleteRecord)
* allow passing options to the client in the initializer
* aliased `default_progress` setting as `progress`
* added `base64` dependency explicitly to the gemspec – fixes a warning in Ruby 3.3, since it will be extracted as an optional gem in 3.4

## [0.3.1] - 2023-10-10

* fixed Minisky not working on Ruby 2.x

## [0.3.0] - 2023-10-05

* authentication improvements & changes:
  - Minisky now automatically manages access tokens, calling `check_access` manually is not necessary (set `auto_manage_tokens` to `false` to disable this)
  - `check_access` now just checks token's expiry time instead of making a request to `getSession`
  - added `send_auth_headers` option – set to `false` to not set auth header automatically, which is the default
  - removed default config file name – explicit file name is now required
  - Minisky can now be used in unauthenticated mode – pass `nil` as the config file name
  - added `reset_tokens` helper method
* refactored response handling – typed errors are now raised on non-success response status
* `user` wrapper can also be used for writing fields to the config
* improved error handling

## [0.2.0] - 2023-09-02

* more consistent handling of parameters in the main methods:
  - `auth` is now a named parameter
  - access token is used by default, pass `nil` or an explicit token as `auth` to override
  - `params` is always optional
* progress dots in `#fetch_all`:
  - default is now to not print anything
  - pass `'.'` or any other character/string to show progress
  - set `default_progress` on the client object to use for all `#fetch_all` calls
* added `max_pages` option to `#fetch_all`
* `#login` and `#perform_token_refresh` methods use the JSON response as return value
* renamed `ident` field in the config hash to `id`
* config is now accessed in `Requests` from the client object as a `config` property instead of `@config` ivar
* config fields are exposed as a `user` wrapper object, e.g. `user.did` delegates to `@config['did']`

## [0.1.0] - 2023-09-01

- extracted most code to a `Requests` module that can be included into a different client class with custom config handling
- added `#check_access` method
- hostname is now passed as a parameter
- config file name can be passed as a parameter
- added tests

## [0.0.1] - 2023-08-30

Initial release – extracted from original gist:

- logging in and refreshing the token
- making GET & POST requests
- fetching paginated responses
