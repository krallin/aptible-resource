module Aptible
  module Resource
    class Adapter < HyperResource::Adapter::HAL_JSON
      class << self
        def get_data_type_from_object(object)
          return nil unless object

          # TODO: Only reference _type
          # See https://github.com/aptible/auth.aptible.com/issues/61
          return nil unless (type = object['_type'] || object['type'])
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
