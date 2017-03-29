module Aptible
  module Resource
    class NullRetryCoordinator
      def initialize(_)
      end

      def retry?(_, _)
        false
      end
    end
  end
end
