require_relative 'minisky'

class Minisky

  #
  # Versions of {Requests#get_request} & {Requests#post_request} that work on Ruby 2.x.
  #

  module Ruby2Compat
    def get_request(method, params = nil, auth: default_auth_mode, headers: nil, **kwargs)
      params ||= kwargs unless kwargs.empty?
      super(method, params, auth: auth, headers: headers)
    end

    def post_request(method, data = nil, auth: default_auth_mode, headers: nil, params: nil, **kwargs)
      data ||= kwargs unless kwargs.empty?
      super(method, data, auth: auth, headers: headers, params: params)
    end
  end
end
