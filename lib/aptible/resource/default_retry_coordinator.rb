module Aptible
  module Resource
    class DefaultRetryCoordinator
      attr_reader :resource, :retry_schedule

      IDEMPOTENT_METHODS = [
        # Idempotent as per RFC
        'DELETE', 'GET', 'HEAD', 'OPTIONS', 'PUT',

        # Idempotent on our APIs
        'PATCH'
      ].freeze

      RETRY_ERRORS = [
        # Ancestor for Errno::X
        SystemCallError,

        # Might be caused by e.g. DNS failure
        SocketError,

        # HTTPClient transfer error
        HTTPClient::TimeoutError,
        HTTPClient::KeepAliveDisconnected,
        HTTPClient::BadResponseError,

        # Bad response
        HyperResource::ServerError
      ].freeze

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
