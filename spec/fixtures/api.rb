require 'aptible/resource'

class Api < Aptible::Resource::Base
  has_many :mainframes
  embeds_many :embedded_mainframes
  embeds_one :best_mainframe

  def namespace
    'Api'
  end

  def root_url
    'https://resource.example.com'
  end
end
