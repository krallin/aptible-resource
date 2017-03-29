require 'spec_helper'

# With webmock (fake connections), to check how we handle timeouts.
describe Aptible::Resource::Base do
  let(:body) { { 'hello' => '1' } }
  let(:json_body) { JSON.unparse(body) }
  let(:domain) { 'api.aptible.com' }

  subject { Api.new(root: "http://#{domain}") }

  context 'server errors' do
    let(:sleeps) { [] }

    def time_slept
      sleeps.sum
    end

    before do
      allow_any_instance_of(Aptible::Resource::DefaultRetryCoordinator)
        .to receive(:sleep) { |_, t| sleeps << t }
    end

    shared_examples 'retry examples' do |method|
      context "#{method.to_s.upcase} requests" do
        it 'should retry a server error' do
          stub_request(method, domain)
            .to_return(body: { error: 'foo' }.to_json, status: 500).then
            .to_return(body: json_body)

          expect(subject.public_send(method).body).to eq(body)
        end

        it 'should retry a server error with no body' do
          stub_request(method, domain)
            .to_return(body: '', status: 502).then
            .to_return(body: json_body)

          expect(subject.public_send(method).body).to eq(body)
        end

        it 'should eventually give up' do
          stub_request(method, domain)
            .to_return(body: { error: 'foo' }.to_json, status: 500)

          expect { subject.public_send(method) }
            .to raise_error(HyperResource::ServerError)
        end

        it 'should not retry a client error' do
          stub_request(method, domain)
            .to_return(body: { error: 'foo' }.to_json, status: 400).then
            .to_return(body: json_body)

          expect { subject.public_send(method) }
            .to raise_error(HyperResource::ClientError)
        end
      end
    end

    include_examples 'retry examples', :delete
    include_examples 'retry examples', :get
    include_examples 'retry examples', :put

    context 'POST requests' do
      it 'should not retry a server error' do
        stub_request(:post, domain)
          .to_return(body: { error: 'foo' }.to_json, status: 504).then
          .to_return(body: json_body)

        expect { subject.post }
          .to raise_error(HyperResource::ServerError)

        expect(time_slept).to eq(0)
      end
    end
  end

  context 'network errors' do
    context 'with mock connections' do
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
      around do |example|
        WebMock.allow_net_connect!
        example.run
        WebMock.disable_net_connect!
      end

      it 'default to 10 seconds of timeout and retry 3 times' do
        # This really relies on how exactly MRI implements Net::HTTP open
        # timeouts
        skip 'MRI implementation-specific' if RUBY_PLATFORM == 'java'

        expect(Timeout).to receive(:timeout)
          .with(10, Net::OpenTimeout)
          .exactly(3).times
          .and_raise(Net::OpenTimeout)

        expect { subject.all }.to raise_error(Faraday::Error::TimeoutError)
      end
    end
  end
end
