require 'aptible/resource/version'
require 'aptible/resource/base'
require 'aptible/resource/default_retry_coordinator'
require 'aptible/resource/null_retry_coordinator'
require 'gem_config'
require 'logger'

module Aptible
  module Resource
    include GemConfig::Base

    RETRY_COORDINATOR_OVERRIDE = :override_retry_coordinator_class

    with_configuration do
      has :retry_coordinator_class,
          classes: [Class],
          default: DefaultRetryCoordinator

      has :user_agent,
          classes: [String],
          default: "aptible-resource #{Aptible::Resource::VERSION}"

      has :logger,
          classes: [Logger],
          default: Logger.new(STDERR).tap { |l| l.level = Logger::WARN }
    end

    class << self
      def without_retry(&block)
        override_retry_coordinator_class(
          Aptible::Resource::NullRetryCoordinator, &block
        )
      end

      def override_retry_coordinator_class(klass)
        Thread.current[RETRY_COORDINATOR_OVERRIDE] = klass
        yield if block_given?
      ensure
        Thread.current[RETRY_COORDINATOR_OVERRIDE] = nil
      end

      def retry_coordinator_class
        override = Thread.current[RETRY_COORDINATOR_OVERRIDE]
        return override if override
        configuration.retry_coordinator_class
      end
    end
  end
end
