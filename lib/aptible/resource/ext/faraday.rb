Faraday::Adapter::NetHttp.class_eval do |cls|
  # Work around https://github.com/lostisland/faraday/issues/561 by treating
  # connection timeouts as... timeouts.
  cls::NET_HTTP_EXCEPTIONS.delete Net::OpenTimeout if defined?(Net::OpenTimeout)
end
