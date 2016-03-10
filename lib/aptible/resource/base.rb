require 'fridge'
require 'active_support'
require 'active_support/inflector'
require 'active_support/core_ext'
require 'date'

# Require vendored HyperResource
$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
require 'hyper_resource'

require 'aptible/resource/adapter'
require 'aptible/resource/errors'
require 'aptible/resource/boolean'

# Open errors that make sense
require 'aptible/resource/ext/faraday'

module Aptible
  module Resource
    # rubocop:disable ClassLength
    class Base < HyperResource
      attr_accessor :token, :errors

      def self.get_data_type_from_response(response)
        return nil unless response && response.body
        adapter.get_data_type_from_object(adapter.deserialize(response.body))
      end

      def self.adapter
        Aptible::Resource::Adapter
      end

      def self.collection_href
        "/#{basename}"
      end

      def self.basename
        name.split('::').last.underscore.pluralize
      end

      # rubocop:disable AbcSize
      def self.all(options = {})
        resource = find_by_url(options[:href] || collection_href, options)
        return [] unless resource
        if resource.links.key?('next')
          options[:href] = resource.links['next'].href
          resource.entries + all(options)
        else
          resource.entries
        end
      end
      # rubocop: enable AbcSize

      def self.where(options = {})
        params = options.except(:token, :root, :namespace, :headers)
        params = normalize_params(params)
        find_by_url("#{collection_href}?#{params.to_query}", options).entries
      end

      def self.find(id, options = {})
        find_by_url("#{collection_href}/#{id}", options)
      end

      def self.find_by_url(url, options = {})
        # REVIEW: Should exception be raised if return type mismatch?
        new(options).find_by_url(url)
      rescue HyperResource::ClientError => e
        if e.response.status == 404
          return nil
        else
          raise e
        end
      end

      def self.create!(params = {})
        token = params.delete(:token)
        resource = new(token: token)
        resource.send(basename).create(normalize_params(params))
      end

      def self.create(params = {})
        create!(params)
      rescue HyperResource::ResponseError => e
        new.tap { |resource| resource.errors = Errors.from_exception(e) }
      end

      # rubocop:disable PredicateName
      def self.has_many(relation)
        define_has_many_getter(relation)
        define_has_many_setter(relation)
      end
      # rubocop:enable PredicateName

      def self.embeds_many(relation)
        define_embeds_many_getter(relation)
        define_has_many_setter(relation)
      end

      def self.field(name, options = {})
        define_method name do
          self.class.cast_field(attributes[name], options[:type])
        end

        # Define ? accessor for Boolean attributes
        define_method("#{name}?") { !!send(name) } if options[:type] == Boolean
      end

      def self.belongs_to(relation)
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
      def self.has_one(relation)
        # Better than class << self + alias_method?
        belongs_to(relation)
      end
      # rubocop:enable PredicateName

      def self.define_has_many_getter(relation)
        define_method relation do
          get unless loaded
          if (memoized = instance_variable_get("@#{relation}"))
            memoized
          elsif links[relation]
            depaginated = self.class.all(href: links[relation].base_href,
                                         headers: headers)
            instance_variable_set("@#{relation}", depaginated)
          end
        end
      end

      def self.embeds_one(relation)
        define_method relation do
          get unless loaded
          objects[relation]
        end
      end

      def self.define_embeds_many_getter(relation)
        define_method relation do
          get unless loaded
          objects[relation].entries
        end
      end

      # rubocop:disable MethodLength
      # rubocop:disable AbcSize
      def self.define_has_many_setter(relation)
        define_method "create_#{relation.to_s.singularize}!" do |params = {}|
          get unless loaded
          links[relation].create(self.class.normalize_params(params))
        end

        define_method "create_#{relation.to_s.singularize}" do |params = {}|
          begin
            send "create_#{relation.to_s.singularize}!", params
          rescue HyperResource::ResponseError => e
            Base.new(root: root_url, namespace: namespace).tap do |base|
              base.errors = Errors.from_exception(e)
            end
          end
        end
      end
      # rubocop: enable AbcSize
      # rubocop:enable MethodLength

      def self.normalize_params(params = {})
        params_array = params.map do |key, value|
          value.is_a?(HyperResource) ? [key, value.href] : [key, value]
        end
        Hash[params_array]
      end

      def self.cast_field(value, type)
        if type == Time
          Time.parse(value) if value
        elsif type == DateTime
          DateTime.parse(value) if value
        else
          value
        end
      end

      def self.faraday_options
        # Default Faraday options. May be overridden by passing
        # faraday_options to the initializer.
        {
          request: {
            open_timeout: 10
          }
        }
      end

      def initialize(options = {})
        if options.is_a?(Hash)
          self.token = options[:token]
          populate_default_options!(options)
        end

        super(options)
      end

      def populate_default_options!(options)
        options[:root] ||= root_url
        options[:namespace] ||= namespace
        options[:headers] ||= {}
        options[:headers]['Content-Type'] = 'application/json'
        return unless options[:token]
        options[:headers]['Authorization'] = "Bearer #{bearer_token}"
      end

      def adapter
        self.class.adapter
      end

      def namespace
        fail 'Resource server namespace must be defined by subclass'
      end

      def root_url
        fail 'Resource server root URL must be defined by subclass'
      end

      def find_by_url(url_or_href)
        resource = dup
        resource.href = url_or_href.gsub(/^#{root}/, '')
        resource.get
      end

      def bearer_token
        case token
        when Aptible::Resource::Base then token.access_token
        when Fridge::AccessToken then token.to_s
        when String then token
        end
      end

      alias_method :_hyperresource_update, :update
      def update!(params)
        _hyperresource_update(self.class.normalize_params(params))
      rescue HyperResource::ResponseError => e
        self.errors = Errors.from_exception(e)
        raise e
      end

      def update(params)
        update!(params)
      rescue HyperResource::ResponseError
        false
      end

      def delete
        super
      rescue HyperResource::ResponseError
        # HyperResource/Faraday choke on empty response bodies
        nil
      end
      alias_method :destroy, :delete

      # NOTE: The following does not update the object in-place
      def reload
        self.class.find_by_url(href, headers: headers)
      end

      def errors
        @errors ||= Aptible::Resource::Errors.new
      end

      def error_html
        errors.full_messages.join('<br />')
      end
    end
    # rubocop:enable ClassLength
  end
end
