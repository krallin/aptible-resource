require 'fridge'

# Require vendored HyperResource
$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
require 'hyper_resource'

require 'aptible/resource/adapter'
require 'aptible/resource/model'

module Aptible
  module Resource
    class Base < HyperResource
      include Model

      attr_accessor :token

      def self.get_data_type_from_response(response)
        return nil unless response && response.body
        adapter.get_data_type_from_object(adapter.deserialize(response.body))
      end

      def self.adapter
        Aptible::Resource::Adapter
      end

      def self.namespace
        @@namespace || name
      end

      # rubocop:disable ClassVars
      def self.inherited(child)
        # Set namespace to first inheriting class
        @@namespace = child.name
      end
      # rubocop:enable ClassVars

      def initialize(options = {})
        if options.is_a?(Hash)
          self.token = options[:token]

          options[:root] ||= root_url
          options[:namespace] ||= self.class.namespace
          options[:headers] ||= { 'Content-Type' => 'application/json' }
          options[:headers].merge!(
            'Authorization' => "Bearer #{bearer_token}"
          ) if options[:token]
        end

        super(options)
      end

      def adapter
        self.class.adapter
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
    end
  end
end

require 'aptible/resource/token'
