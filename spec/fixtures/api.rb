require 'aptible/resource'

class Api < Aptible::Resource::Base
  def root_url
    'https://resource.example.com'
  end
end
