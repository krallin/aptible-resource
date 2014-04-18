require 'active_support/inflector'

module Aptible
  module Resource
    module Model
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def collection_href
          "/#{basename}"
        end

        def basename
          name.split('::').last.downcase.pluralize
        end

        def all(options = {})
          resource = find_by_url(collection_href, options)
          return [] unless resource
          resource.send(basename).entries
        end

        def find(id, options = {})
          find_by_url("#{collection_href}/#{id}", options)
        end

        def find_by_url(url, options = {})
          # REVIEW: Should exception be raised if return type mismatch?
          new(options).find_by_url(url)
        rescue HyperResource::ClientError => e
          if e.response.status == 404
            return nil
          else
            raise e
          end
        end

        def create(params)
          token = params.delete(:token)
          resource = new(token: token)
          resource.send(basename).create(normalize_params(params))
        end

        # rubocop:disable PredicateName
        def has_many(relation)
          define_has_many_getter(relation)
          define_has_many_setter(relation)
        end
        # rubocop:enable PredicateName

        def belongs_to(relation)
          define_method relation do
            get unless loaded
            if (memoized = instance_variable_get("@#{relation}"))
              memoized
            elsif links[relation]
              instance_variable_set("@#{relation}", links[relation].get)
            end
          end
        end

        # rubocop:disable PredicateName
        def has_one(relation)
          # Better than class << self + alias_method?
          belongs_to(relation)
        end
        # rubocop:enable PredicateName

        def define_has_many_getter(relation)
          define_method relation do
            get unless loaded
            if (memoized = instance_variable_get("@#{relation}"))
              memoized
            elsif links[relation]
              instance_variable_set("@#{relation}", links[relation].entries)
            end
          end
        end

        def define_has_many_setter(relation)
          define_method "create_#{relation.to_s.singularize}" do |params = {}|
            get unless loaded
            links[relation].create(self.class.normalize_params(params))
          end
        end

        def normalize_params(params = {})
          params_array = params.map do |key, value|
            value.is_a?(HyperResource) ? [key, value.href] : [key, value]
          end
          Hash[params_array]
        end
      end

      def delete
        # HyperResource/Faraday choke on empty response bodies
        super
      rescue HyperResource::ResponseError
        nil
      end
      alias_method :destroy, :delete

      def update(params)
        super(self.class.normalize_params(params))
      end

      # NOTE: The following does not update the object in-place
      def reload
        self.class.find_by_url(href, headers: headers)
      end
    end
  end
end
