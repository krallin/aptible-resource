module Aptible
  module Resource
    class Errors
      attr_accessor :status_code, :messages, :full_messages

      def self.from_exception(exception)
        new.tap do |errors|
          response_json = JSON.parse(exception.response.body)
          errors.messages = { base: response_json['message'] }
          errors.full_messages = [response_json['message']]
          errors.status_code = exception.response.status
        end
      end

      def messages
        @messages ||= {}
      end

      def full_messages
        @full_messages ||= []
      end

      def any?
        full_messages.any?
      end
    end
  end
end
