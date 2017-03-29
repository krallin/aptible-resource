class HyperResource
  module Modules
    module HTTP
      class WrapErrors < Faraday::Middleware
        class WrappedError < StandardError
          attr_reader :method, :err

          def initialize(method, err)
            @method = method
            @err = err
          end
        end

        def call(env)
          @app.call(env)
        rescue StandardError => e
          raise WrappedError.new(env.method, e)
        end
      end
    end
  end
end
