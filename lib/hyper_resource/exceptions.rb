class HyperResource
  class Exception < ::StandardError
    ## The internal exception which led to this one, if any.
    attr_accessor :cause

    def initialize(message, attrs={}) # @private
      self.cause = attrs[:cause]
      super(message)
    end
  end

  class ResponseError < Exception
    ## The +Faraday::Response+ object which led to this exception.
    attr_accessor :response

    ## The deserialized response body which led to this exception.
    ## May be blank, e.g. in case of deserialization errors.
    attr_accessor :body

    def initialize(message, attrs={}) # @private
      self.response = attrs[:response]
      self.body = attrs[:body]

      ## Try to help out with the message
      if body
        if (error = body['error'])
          message = "#{message} (#{error})"
        end
        if (error_message = body['message'])
          message = "#{message} (#{error_message})"
        end
      elsif response
        message = "#{message} (#{response.body})"
      end

      super(message, attrs)
    end
  end

  class ClientError < ResponseError; end
  class ServerError < ResponseError; end
end

