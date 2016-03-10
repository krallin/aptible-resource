$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

# Load shared spec files
Dir["#{File.dirname(__FILE__)}/shared/**/*.rb"].each do |file|
  require file
end
# Load spec fixtures
Dir["#{File.dirname(__FILE__)}/fixtures/**/*.rb"].each do |file|
  require file
end

# Require library up front
require 'aptible/resource'

# Webmock
require 'webmock/rspec'
WebMock.allow_net_connect!
