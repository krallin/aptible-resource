module Aptible
  module Resource
    class DefaultRetryCoordinator
      attr_reader :resource, :retry_schedule

      IDEMPOTENT_METHODS = [:delete, :get, :head, :options, :put].freeze

      def initialize(resource)
        @resource = resource
        @retry_schedule = new_retry_schedule
      end

      def retry?(e)
        return false unless e.is_a?(HyperResource::ServerError)
        return false unless IDEMPOTENT_METHODS.include?(e.response.env.method)
        retry_in = retry_schedule.shift
        return false if retry_in.nil?
        sleep retry_in
        true
      end

      private

      def new_retry_schedule
        [0.2, 0.8, 2]
      end
    end
  end
end
