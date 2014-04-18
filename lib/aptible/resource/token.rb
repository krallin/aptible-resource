require 'aptible/resource/base'

# Skeleton class for token implementations to inherit from
module Aptible
  module Resource
    class Token < Base
      attr_accessor :access_token
    end
  end
end
