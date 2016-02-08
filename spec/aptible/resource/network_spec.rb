require 'spec_helper'

describe Aptible::Resource::Base, slow: true do
  subject { Api.new(root: 'http://10.255.255.1/') }

  it 'should time out by default after a reasonable delay' do
    # Faraday throws different kinds of errors depending on whether
    # Net::OpenTimeout is defined, so let's check for this
    # https://github.com/lostisland/faraday/issues/561
    e = Faraday::Error::TimeoutError
    e = Faraday::Error::ConnectionFailed if defined? Net::OpenTimeout

    expect do
      Timeout.timeout(15) { subject.all }
    end.to raise_error(e, 'execution expired')
  end
end
