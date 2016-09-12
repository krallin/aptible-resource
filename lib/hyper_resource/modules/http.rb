require 'faraday'
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

      ## Loads and returns the resource pointed to by +href+.  The returned
      ## resource will be blessed into its "proper" class, if
      ## +self.class.namespace != nil+.
      def get
        execute_request { faraday_connection.get(href || '') }
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
        execute_request do
          faraday_connection.post { |req| req.body = adapter.serialize(attrs) }
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
        execute_request do
          faraday_connection.put { |req| req.body = adapter.serialize(attrs) }
        end
      end

      ## PATCHes this resource's changed attributes to this resource's href,
      ## and returns the response resource.  If attributes are given, +patch+
      ## uses those instead.
      def patch(attrs = nil)
        attrs ||= attributes.changed_attributes
        execute_request do
          faraday_connection.patch { |req| req.body = adapter.serialize(attrs) }
        end
      end

      ## DELETEs this resource's href, and returns the response resource.
      def delete
        execute_request { faraday_connection.delete }
      end

      ## Returns a raw Faraday connection to this resource's URL, with proper
      ## headers (including auth).
      def faraday_connection(url = nil)
        url ||= URI.join(root, href)

        Faraday.new(faraday_options.merge(url: url)) do |builder|
          builder.headers.merge!(headers || {})
          builder.headers['User-Agent'] = Aptible::Resource.configuration
                                                           .user_agent

          if (ba = auth[:basic])
            builder.basic_auth(*ba)
          end

          builder.request :url_encoded
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
      end

      private

      def execute_request
        raise 'execute_request needs a block!' unless block_given?
        retry_coordinator = Aptible::Resource.configuration
                                             .retry_coordinator_class.new(self)

        n_retry = 0
        begin
          finish_up(yield)
        rescue HyperResource::ResponseError => e
          n_retry += 1
          raise e if n_retry > MAX_COORDINATOR_RETRIES
          retry if retry_coordinator.retry?(e)
          raise e
        end
      end

      def finish_up(response)
        begin
          body = adapter.deserialize(response.body) unless response.body.nil?
        rescue StandardError => e
          raise HyperResource::ResponseError.new(
            'Error when deserializing response body',
            response: response,
            cause: e
          )
        end

        status = response.status
        if status / 100 == 2
        elsif status / 100 == 3
          raise 'HyperResource does not handle redirects'
        elsif status / 100 == 4
          raise HyperResource::ClientError.new(status.to_s,
                                               response: response,
                                               body: body)
        elsif status / 100 == 5
          raise HyperResource::ServerError.new(status.to_s,
                                               response: response,
                                               body: body)

        else ## 1xx? really?
          raise HyperResource::ResponseError.new("Got status #{status}, wtf?",
                                                 response: response,
                                                 body: body)

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
