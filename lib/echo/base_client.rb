module Echo
  class BaseClient
    include Echo::QueryTransformations

    def connection
      @connection ||= build_connection
    end

    def initialize(root, urs_client_id=nil)
      @root = root
      @urs_client_id = urs_client_id
    end

    protected

    def client_id
      Rails.configuration.cmr_client_id
    end

    def default_headers
      {}
    end

    def token_header(token)
      {'Echo-Token': ENV['cmr_echo_token']}
      # TODO(aimee): Re-implement this code.
      # Right now, MAAP CMR requires an admin token for search collection requests.
      #
      # # Token is a URS token, as opposed to an ECHO token
      # token = "#{token}:#{@urs_client_id}" if token.present? && !token.include?('-')
      # token.present? ? {'Echo-Token' => "#{token}"} : {}
    end

    def request(method, url, params, body, headers, options)
      faraday_response = connection.send(method, url, params) do |req|

        req.headers['Content-Type'] = 'application/json' unless method == :get
        default_headers.each do |header, value|
          req.headers[header] = value
        end
        headers.each do |header, value|
          req.headers[header] = value
        end
        options.each do |opt, value|
          req.options[opt] = value
        end
        req.body = body if body
      end
      Echo::Response.new(faraday_response)
    end

    def get(url, params={}, headers={}, options={})
      request(:get, url, params, nil, headers, options)
    end

    def delete(url, params={}, body=nil, headers={}, options={})
      request(:delete, url, params, body, headers, options)
    end

    def post(url, body, headers={}, options={})
      request(:post, url, nil, body, headers, options)
    end

    def put(url, body, headers={}, options={})
      request(:put, url, nil, body, headers, options)
    end

    def build_connection
      Faraday.new(:url => @root) do |conn|
        conn.use Echo::ClientMiddleware::LoggingMiddleware

        # The order of these handlers is important.  They are run last to first.
        # Our parsers depend on JSON / XML being converted to objects by earlier
        # parsers.
        conn.use Echo::ClientMiddleware::ErrorsMiddleware, :content_type => /\bjson$/
        conn.response :json, :content_type => /\bjson$/
        conn.use Echo::ClientMiddleware::Echo10GranuleMiddleware, :content_type => /^application\/(echo10\+)?xml$/
        conn.use Echo::ClientMiddleware::Echo10CollectionMiddleware, :content_type => /^application\/(echo10\+)?xml$/
        conn.response :xml, :content_type => /\bxml$/

        yield(conn) if block_given?

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
