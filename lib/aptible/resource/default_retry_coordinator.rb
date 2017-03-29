module Aptible
  module Resource
    class DefaultRetryCoordinator
      attr_reader :resource, :retry_schedule

      IDEMPOTENT_METHODS = [:delete, :get, :head, :options, :put].freeze
      RETRY_ERRORS = [Faraday::Error, HyperResource::ServerError].freeze

      def initialize(resource)
        @resource = resource
        @retry_schedule = new_retry_schedule
      end

      def retry?(method, err)
        # rubocop:disable Style/CaseEquality
        return false unless RETRY_ERRORS.any? { |c| c === err }
        return false unless IDEMPOTENT_METHODS.include?(method)
        retry_in = retry_schedule.shift
        return false if retry_in.nil?
        sleep retry_in
        true
        # rubocop:enable Style/CaseEquality
      end

      private

      def new_retry_schedule
        [0.2, 0.8, 2]
      end
    end
  end
end
