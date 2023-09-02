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

Initial release - extracted from original gist:

- logging in and refreshing the token
- making GET & POST requests
- fetching paginated responses
