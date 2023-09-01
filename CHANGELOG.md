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
