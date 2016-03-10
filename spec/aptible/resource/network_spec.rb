require 'spec_helper'

# With webmock (fake connections), to check how we handle timeouts.
describe Aptible::Resource::Base do
  let(:body) { { 'hello' => '1' } }
  let(:json_body) { JSON.unparse(body) }
  let(:domain) { 'api.aptible.com' }

  subject { Api.new(root: "http://#{domain}") }

  context 'with mock connections' do
    around do |example|
      WebMock.disable_net_connect!
      example.run
      WebMock.allow_net_connect!
    end

    it 'should retry timeout errors' do
      stub_request(:get, domain)
        .to_timeout.then
        .to_timeout.then
        .to_return(body: json_body)

      expect(subject.get.body).to eq(body)
    end

    it 'should not retry POSTs' do
      stub_request(:post, domain)
        .to_timeout.then
        .to_return(body: json_body)

      expect { subject.post }.to raise_error(Faraday::TimeoutError)
    end
  end

  context 'without connections' do
    it 'default to 10 seconds of timeout and retry 3 times' do
      # This really relies on how exactly MRI implements Net::HTTP open timeouts
      skip 'MRI implementation-specific' if RUBY_PLATFORM == 'java'

      expect(Timeout).to receive(:timeout)
        .with(10, Net::OpenTimeout)
        .exactly(3).times
        .and_raise(Net::OpenTimeout)

      expect { subject.all }.to raise_error(Faraday::Error::TimeoutError)
    end
  end
end
