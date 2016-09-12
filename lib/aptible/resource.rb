require 'aptible/resource/version'
require 'aptible/resource/base'
require 'aptible/resource/default_retry_coordinator'
require 'gem_config'

module Aptible
  module Resource
    include GemConfig::Base

    with_configuration do
      has :retry_coordinator_class,
          classes: [Class],
          default: DefaultRetryCoordinator

      has :user_agent,
          classes: [String],
          default: "aptible-resource #{Aptible::Resource::VERSION}"
    end
  end
end
