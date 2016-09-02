module Aptible
  module Resource
    class DefaultRetryCoordinator
      attr_reader :resource

      def initialize(resource)
        @resource = resource
      end

      def retry?(_error)
        false
      end
    end
  end
end
