module Hawk
  module Server
    extend self

    def authenticate(authorization_header, options)
      Hawk::AuthorizationHeader.authenticate(authorization_header, options)
    end

    def authenticate_bewit(bewit, options)
      padding = '=' * ((4 - bewit.size) % 4)
      id, timestamp, mac, ext = Base64.decode64(bewit + padding).split('\\')

      unless options[:credentials_lookup].respond_to?(:call) && (credentials = options[:credentials_lookup].call(id))
        return AuthenticationFailure.new(:id, "Unidentified id")
      end

      if Time.at(timestamp.to_i) < Time.now
        return AuthenticationFailure.new(:ts, "Stale timestamp")
      end

      expected_bewit = Crypto.bewit(
        :credentials => credentials,
        :host => options[:host],
        :request_uri => remove_bewit_param_from_path(options[:request_uri]),
        :port => options[:port],
        :method => options[:method],
        :ts => timestamp,
        :ext => ext
      )

      unless expected_bewit == bewit
        return AuthenticationFailure.new(:bewit, "Invalid signature")
      end

      credentials
    end

    def build_authorization_header(options)
      Hawk::AuthorizationHeader.build(options, [:hash, :ext, :mac])
    end

    private

    def remove_bewit_param_from_path(path)
      path, query = path.split('?')
      return path unless query
      query, fragment = query.split('#')
      query = query.split('&').reject { |i| i =~ /\Abewit=/ }.join('&')
      path << "?#{query}" if query != ''
      path << "#{fragment}" if fragment
      path
    end
  end
end
