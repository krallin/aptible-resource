module Aptible
  module Resource
    class Adapter < HyperResource::Adapter::HAL_JSON
      class << self
        def get_data_type_from_object(object)
          return nil unless object

          if (type = object['_type'])
            if type.respond_to?(:camelize)
              type.camelize
            else
              type[0].upcase + type[1..-1]
            end
          end
        end
      end
    end
  end
end
