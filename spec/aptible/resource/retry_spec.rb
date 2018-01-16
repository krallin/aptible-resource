require 'spec_helper'

# With webmock (fake connections), to check how we handle timeouts.
describe Aptible::Resource::Base do
  let(:body) do
    { 'hello' => '1', '_links' => { 'self' => { 'href' => href } } }
  end
  let(:json_body) { JSON.unparse(body) }
  let(:href) { 'https://resource.example.com/mainframes/1' }

  subject do
    stub = stub_request(:get, href).to_return(body: json_body)
    begin
      Api::Mainframe.find(1)
    ensure
      remove_request_stub(stub)
    end
  end

  let(:sleeps) { [] }

  def time_slept
    sleeps.sum
  end

  before do
    allow_any_instance_of(Aptible::Resource::DefaultRetryCoordinator)
      .to receive(:sleep) { |_, t| sleeps << t }
  end

  context 'server errors' do
    shared_examples 'retry examples' do |method|
      context "#{method.to_s.upcase} requests" do
        it 'should retry a server error' do
          stub_request(method, href)
            .to_return(body: { error: 'foo' }.to_json, status: 500).then
            .to_return(body: json_body)

          expect(subject.public_send(method).body).to eq(body)
        end

        it 'should retry a server error with no body' do
          stub_request(method, href)
            .to_return(body: '', status: 502).then
            .to_return(body: json_body)

          expect(subject.public_send(method).body).to eq(body)
        end

        it 'should eventually give up' do
          stub_request(method, href)
            .to_return(body: { error: 'foo' }.to_json, status: 500)

          expect { subject.public_send(method) }
            .to raise_error(HyperResource::ServerError)
        end

        it 'should not retry a client error' do
          stub_request(method, href)
            .to_return(body: { error: 'foo' }.to_json, status: 400).then
            .to_return(body: json_body)

          expect { subject.public_send(method) }
            .to raise_error(HyperResource::ClientError)
        end

        it 'should not retry parse errors' do
          stub_request(method, href)
            .to_return(body: 'boo', status: 400).then
            .to_return(body: json_body)

          expect { subject.public_send(method) }
            .to raise_error(HyperResource::ResponseError)
        end
      end
    end

    include_examples 'retry examples', :delete
    include_examples 'retry examples', :get
    include_examples 'retry examples', :put
    include_examples 'retry examples', :patch

    context 'POST requests' do
      it 'should not retry a server error' do
        stub_request(:post, href)
          .to_return(body: { error: 'foo' }.to_json, status: 504).then
          .to_return(body: json_body)

        expect { subject.post }
          .to raise_error(HyperResource::ServerError)

        expect(time_slept).to eq(0)
      end
    end

    context 'retry coordinator overrides' do
      before do
        stub_request(:get, href)
          .to_return(body: { error: 'foo' }.to_json, status: 500).then
          .to_return(body: { status: 'ok' }.to_json, status: 200)
      end

      it 'should be overridden by override_retry_coordinator_class ' do
        expect do
          klass = Aptible::Resource::NullRetryCoordinator
          Aptible::Resource.override_retry_coordinator_class(klass) do
            subject.get
          end
        end.to raise_error(HyperResource::ServerError)
      end

      it 'should disable retries with override_retry_coordinator_class' do
        expect { Aptible::Resource.without_retry { subject.get } }
          .to raise_error(HyperResource::ServerError)
      end
    end
  end

  context 'network errors' do
    context 'with mock connections' do
      it 'should retry timeout errors' do
        stub_request(:get, href)
          .to_timeout.then
          .to_timeout.then
          .to_return(body: json_body)

        expect(subject.get.body).to eq(body)
      end

      it 'should retry timeout errors (Errno::ETIMEDOUT)' do
        stub_request(:get, href)
          .to_raise(Errno::ETIMEDOUT).then
          .to_raise(Errno::ETIMEDOUT).then
          .to_return(body: json_body)

        expect(subject.get.body).to eq(body)
      end

      it 'should retry connection errors' do
        stub_request(:get, href)
          .to_raise(Errno::ECONNREFUSED).then
          .to_raise(Errno::ECONNREFUSED).then
          .to_return(body: json_body)

        expect(subject.get.body).to eq(body)
      end

      it 'should not retry POSTs' do
        stub_request(:post, href)
          .to_timeout.then
          .to_return(body: json_body)

        expect { subject.post }
          .to raise_error(HTTPClient::TimeoutError)
      end
    end
  end
end
