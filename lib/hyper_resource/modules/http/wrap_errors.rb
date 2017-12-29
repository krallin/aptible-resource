class HyperResource
  module Modules
    module HTTP
      module WrapErrors
        class WrappedError < StandardError
          attr_reader :method, :err

          def initialize(method, err)
            @method = method
            @err = err
          end
        end
      end
    end
  end
end
