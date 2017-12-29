require 'httpclient'
require 'uri'
require 'json'
require 'digest/md5'

class HyperResource
  module Modules
    module HTTP
      # A (high) limit to the number of retries a coordinator can ask for. This
      # is to avoid breaking things if we have a buggy coordinator that retries
      # things over and over again.
      MAX_COORDINATOR_RETRIES = 16

      CONTENT_TYPE_HEADERS = {
        'Content-Type' => 'application/json; charset=utf-8'
      }.freeze

      class << self
        attr_reader :http_client

        def initialize_http_client!
          @http_client = HTTPClient.new.tap do |c|
            c.cookie_manager = nil
            c.connect_timeout = 30
            c.send_timeout = 45
            c.receive_timeout = 30
            c.keep_alive_timeout = 15
            c.ssl_config.set_default_paths
          end
        end
      end

      # We use this accessor / initialize as opposed to a simple constant
      # because during specs, Webmock stubs the HTTPClient class, but that's
      # happens after we initialized  the constant (we could work around that
      # by loading Webmock first, but this is just as simple.
      initialize_http_client!

      ## Loads and returns the resource pointed to by +href+.  The returned
      ## resource will be blessed into its "proper" class, if
      ## +self.class.namespace != nil+.
      def get
        execute_request('GET') do |uri, headers|
          HTTP.http_client.get(
            uri,
            follow_redirect: true,
            header: headers
          )
        end
      end

      ## By default, calls +post+ with the given arguments. Override to
      ## change this behavior.
      def create(*args)
        post(*args)
      end

      ## POSTs the given attributes to this resource's href, and returns
      ## the response resource.
      def post(attrs = nil)
        attrs ||= attributes

        execute_request('POST') do |uri, headers|
          HTTP.http_client.post(
            uri,
            body: adapter.serialize(attrs),
            header: headers.merge(CONTENT_TYPE_HEADERS)
          )
        end
      end

      ## By default, calls +put+ with the given arguments.  Override to
      ## change this behavior.
      def update(*args)
        put(*args)
      end

      ## PUTs this resource's attributes to this resource's href, and returns
      ## the response resource.  If attributes are given, +put+ uses those
      ## instead.
      def put(attrs = nil)
        attrs ||= attributes

        execute_request('PUT') do |uri, headers|
          HTTP.http_client.put(
            uri,
            body: adapter.serialize(attrs),
            header: headers.merge(CONTENT_TYPE_HEADERS)
          )
        end
      end

      ## PATCHes this resource's changed attributes to this resource's href,
      ## and returns the response resource.  If attributes are given, +patch+
      ## uses those instead.
      def patch(attrs = nil)
        attrs ||= attributes.changed_attributes

        execute_request('PATCH') do |uri, headers|
          HTTP.http_client.patch(
            uri,
            body: adapter.serialize(attrs),
            header: headers.merge(CONTENT_TYPE_HEADERS)
          )
        end
      end

      ## DELETEs this resource's href, and returns the response resource.
      def delete
        execute_request('DELETE') do |uri, headers|
          HTTP.http_client.delete(uri, header: headers)
        end
      end

      private

      def execute_request(method)
        raise 'execute_request needs a block!' unless block_given?
        retry_coordinator = Aptible::Resource.retry_coordinator_class.new(self)

        uri = URI.join(root, href)

        h = headers || {}
        h['User-Agent'] = Aptible::Resource.configuration.user_agent

        n_retry = 0

        begin
          t0 = Time.now

          begin
            res = yield(uri, h)
            entity = finish_up(res)
          rescue StandardError => e
            Aptible::Resource.configuration.logger.info([
              method,
              uri,
              "(#{n_retry})",
              "#{(Time.now - t0).round(2)}s",
              "ERR[#{e.class}: #{e}]"
            ].join(' '))

            raise WrapErrors::WrappedError.new(method, e)
          else
            Aptible::Resource.configuration.logger.info([
              method,
              uri,
              "(#{n_retry})",
              "#{(Time.now - t0).round(2)}s",
              res.status
            ].join(' '))

            entity
          end
        rescue WrapErrors::WrappedError => e
          n_retry += 1
          raise e.err if n_retry > MAX_COORDINATOR_RETRIES
          retry if retry_coordinator.retry?(e.method, e.err)
          raise e.err
        end
      end

      def finish_up(response)
        body = adapter_error = nil

        begin
          body = adapter.deserialize(response.body) unless response.body.nil?
        rescue StandardError => e
          adapter_error = e
        end

        status = response.status

        if status / 100 == 2
        elsif status / 100 == 3
          raise 'HyperResource does not handle redirects'
        elsif status / 100 == 4
          raise HyperResource::ClientError.new(
            status.to_s,
            response: response,
            body: body
          )
        elsif status / 100 == 5
          raise HyperResource::ServerError.new(
            status.to_s,
            response: response,
            body: body
          )
        else ## 1xx? really?
          raise HyperResource::ResponseError.new(
            "Got status #{status}, wtf?",
            response: response,
            body: body
          )

        end

        if adapter_error
          raise HyperResource::ResponseError.new(
            'Error when deserializing response body',
            response: response,
            cause: e
          )
        end

        # Unfortunately, HyperResource insists on having response and body
        # be attributes..
        self.response = response
        self.body = body
        adapter.apply(body, self)
        self.loaded = true

        to_response_class
      end
    end
  end
end
