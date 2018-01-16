require 'spec_helper'

describe Aptible::Resource::Base do
  let(:hyperresource_exception) { HyperResource::ResponseError.new('403') }
  let(:error_response) { double 'Faraday::Response' }
  before { hyperresource_exception.stub(:response) { error_response } }
  before do
    error_response.stub(:body) { { message: 'Forbidden' }.to_json }
    error_response.stub(:status) { 403 }
  end

  shared_context 'paginated collection' do
    let(:urls) { ['/mainframes', '/mainframes?page=1'] }
    let(:calls) { [] }

    before do
      pages = {}

      urls.each_with_index do |url, idx|
        collection = double("Collection for #{url}")
        links = {}

        allow(collection).to receive(:entries).and_return(["At #{url}"])
        allow(collection).to receive(:links).and_return(links)

        next_url = urls[idx + 1]
        if next_url
          links['next'] = HyperResource::Link.new(nil, 'href' => next_url)
        end

        pages[url] = collection
      end

      [Api, Api::Mainframe].each do |klass|
        allow_any_instance_of(klass).to receive(:find_by_url) do |_, u, _|
          calls << u
          page = pages[u]
          raise "Accessed unexpected URL #{u}" if page.nil?
          page
        end
      end
    end
  end

  subject { Api.new }

  describe '.collection_href' do
    it 'should use the pluralized resource name' do
      url = Api::Mainframe.collection_href
      expect(url).to eq '/mainframes'
    end
  end

  describe '.find' do
    it 'should find' do
      stub_request(
        :get, 'https://resource.example.com/mainframes/42'
      ).to_return(body: { id: 42 }.to_json, status: 200)

      m = Api::Mainframe.find(42)
      expect(m.id).to eq(42)
    end

    it 'should find with query params' do
      stub_request(
        :get, 'https://resource.example.com/mainframes/42?test=123'
      ).to_return(body: { id: 42 }.to_json, status: 200)

      m = Api::Mainframe.find(42, test: 123)
      expect(m.id).to eq(42)
    end

    it 'should return an instance of the correct class' do
      stub_request(
        :get, 'https://resource.example.com/mainframes/42'
      ).to_return(body: { id: 42 }.to_json, status: 200)

      m = Api::Mainframe.find(42)
      expect(m).to be_a(Api::Mainframe)
    end
  end

  describe '.all' do
    context 'when not paginated' do
      let(:mainframe) { double 'Mainframe' }
      let(:collection) { double 'Api' }

      before do
        collection.stub(:entries) { [mainframe] }
        collection.stub(:links) { Hash.new }
        Api::Mainframe.any_instance.stub(:find_by_url) { collection }
      end

      it 'should be an array' do
        expect(Api::Mainframe.all).to be_a Array
      end

      it 'should return the root collection' do
        expect(Api::Mainframe.all).to eq [mainframe]
      end

      it 'should pass options to the HyperResource initializer' do
        klass = Api::Mainframe
        options = { token: 'token' }
        expect(klass).to receive(:new).with(options).and_return klass.new
        Api::Mainframe.all(options)
      end
    end

    context 'when paginated' do
      include_context 'paginated collection'

      it 'should collect entries from all pages' do
        records = Api::Mainframe.all
        expect(records.size).to eq(2)
        expect(records.first).to eq('At /mainframes')
        expect(records.second).to eq('At /mainframes?page=1')
        expect(calls).to eq(urls)
      end

      it "should return an empty list for a URL that doesn't exist" do
        allow_any_instance_of(Api::Mainframe).to receive(:find_by_url) { nil }
        expect(Api::Mainframe.all).to eq([])
      end
    end
  end

  describe '.each_page' do
    include_context 'paginated collection'

    it 'should iterate over all pages' do
      pages = 0
      Api::Mainframe.each_page { pages += 1 }
      expect(pages).to eq(2)
      expect(calls).to eq(urls)
    end

    it 'should find all records' do
      records = ['At /mainframes', 'At /mainframes?page=1']
      Api::Mainframe.each_page { |p| expect(p).to eq([records.shift]) }
      expect(calls).to eq(urls)
    end

    it 'should not access more URLs if the consumer breaks' do
      Api::Mainframe.each_page { break }
      expect(calls).to eq(['/mainframes'])
    end

    it 'should return an enum if no block is given' do
      e = Api::Mainframe.each_page
      pages = 0
      e.each { pages += 1 }
      expect(pages).to eq(2)
      expect(calls).to eq(urls)
    end
  end

  describe '.create' do
    let(:mainframe) { Api::Mainframe.new }
    let(:mainframes_link) { HyperResource::Link.new(href: '/mainframes') }

    before { Api.any_instance.stub(:mainframes) { mainframes_link } }
    before { mainframes_link.stub(:create) { mainframe } }

    it 'should create a new top-level resource' do
      mainframes_link.stub(:create) { mainframe }
      expect(mainframes_link).to receive(:create).with(foo: 'bar')
      Api::Mainframe.create(foo: 'bar')
    end

    it 'should populate #errors in the event of an error' do
      mainframes_link.stub(:create) { raise hyperresource_exception }
      mainframe = Api::Mainframe.create
      expect(mainframe.errors.messages).to eq(base: 'Forbidden')
      expect(mainframe.errors.full_messages).to eq(['Forbidden'])
    end

    it 'should return a Base-classed resource on error' do
      mainframes_link.stub(:create) { raise hyperresource_exception }
      expect(Api::Mainframe.create).to be_a Api::Mainframe
    end

    it 'should return the object in the event of successful creation' do
      mainframes_link.stub(:create) { mainframe }
      expect(Api::Mainframe.create).to eq mainframe
    end
  end

  describe '.create!' do
    let(:mainframe) { Api::Mainframe.new }
    let(:mainframes_link) { HyperResource::Link.new(href: '/mainframes') }

    before { Api.any_instance.stub(:mainframes) { mainframes_link } }
    before { mainframes_link.stub(:create) { mainframe } }

    it 'should pass through any exceptions' do
      mainframes_link.stub(:create) { raise hyperresource_exception }
      expect do
        Api::Mainframe.create!
      end.to raise_error HyperResource::ResponseError
    end

    it 'should return the object in the event of successful creation' do
      mainframes_link.stub(:create) { mainframe }
      expect(Api::Mainframe.create!).to eq mainframe
    end
  end

  describe '#initialize' do
    it 'should be a HyperResource instance' do
      expect(subject).to be_a HyperResource
    end

    it 'should require root_url to be defined' do
      expect { described_class.new }.to raise_error
    end
  end

  describe '#bearer_token' do
    it 'should accept an Aptible::Resource::Token' do
      token = Api::Token.new
      token.stub(:access_token) { 'aptible_auth_token' }
      subject.stub(:token) { token }
      expect(subject.bearer_token).to eq token.access_token
    end

    it 'should accept a Fridge::AccessToken' do
      token = Fridge::AccessToken.new
      token.stub(:to_s) { 'fridge_access_token' }
      subject.stub(:token) { token }
      expect(subject.bearer_token).to eq token.to_s
    end

    it 'should accept a String' do
      subject.stub(:token) { 'token' }
      expect(subject.bearer_token).to eq 'token'
    end
  end

  describe '#errors' do
    it 'should default to an empty error' do
      expect(subject.errors).to be_a Aptible::Resource::Errors
      expect(subject.errors.messages).to eq({})
      expect(subject.errors.full_messages).to eq([])
    end
  end

  describe '#update' do
    it 'should populate #errors in the event of an error' do
      HyperResource.any_instance.stub(:put) { raise hyperresource_exception }
      subject.update({})
      expect(subject.errors.messages).to eq(base: 'Forbidden')
      expect(subject.errors.full_messages).to eq(['Forbidden'])
    end

    it 'should return false in the event of an error' do
      HyperResource.any_instance.stub(:put) { raise hyperresource_exception }
      expect(subject.update({})).to eq false
    end

    it 'should return the object in the event of a successful update' do
      HyperResource.any_instance.stub(:put) { subject }
      expect(subject.update({})).to eq subject
    end
  end

  describe '#update!' do
    it 'should populate #errors in the event of an error' do
      HyperResource.any_instance.stub(:put) { raise hyperresource_exception }
      begin
        subject.update!({})
      rescue
        # Allow errors to be populated and tested
        nil
      end
      expect(subject.errors.messages).to eq(base: 'Forbidden')
      expect(subject.errors.full_messages).to eq(['Forbidden'])
    end

    it 'should pass through any exceptions' do
      HyperResource.any_instance.stub(:put) { raise hyperresource_exception }
      expect do
        subject.update!({})
      end.to raise_error HyperResource::ResponseError
    end

    it 'should return the object in the event of a successful update' do
      HyperResource.any_instance.stub(:put) { subject }
      expect(subject.update!({})).to eq subject
    end
  end

  describe '#delete' do
    it 'allows an empty response' do
      stub_request(:delete, subject.root_url).to_return(body: '', status: 200)
      expect(subject.delete).to be_nil
    end

    it 'ignores 404s' do
      stub_request(:delete, subject.root_url).to_return(body: '', status: 404)
      expect(subject.delete).to be_nil
    end
  end

  context '.has_many' do
    let(:mainframe) { Api::Mainframe.new }
    let(:mainframes_link) { HyperResource::Link.new(href: '/mainframes') }

    before { subject.stub(:loaded) { true } }
    before { subject.stub(:links) { { mainframes: mainframes_link } } }
    before { mainframes_link.stub(:entries) { [mainframe] } }
    before { mainframes_link.stub(:base_href) { '/mainframes' } }

    describe '#create_#{relation}' do
      it 'should populate #errors in the event of an error' do
        mainframes_link.stub(:create) { raise hyperresource_exception }
        mainframe = subject.create_mainframe({})
        expect(mainframe.errors.messages).to eq(base: 'Forbidden')
        expect(mainframe.errors.full_messages).to eq(['Forbidden'])
      end

      it 'should return a Base-classed resource on error' do
        mainframes_link.stub(:create) { raise hyperresource_exception }
        expect(subject.create_mainframe.class).to eq Aptible::Resource::Base
      end

      it 'should have errors present on error' do
        mainframes_link.stub(:create) { raise hyperresource_exception }
        expect(subject.create_mainframe.errors.any?).to be true
      end

      it 'should return the object in the event of successful creation' do
        mainframes_link.stub(:create) { mainframe }
        expect(subject.create_mainframe({})).to eq mainframe
      end

      it 'should have no errors on successful creation' do
        mainframes_link.stub(:create) { mainframe }
        expect(subject.create_mainframe.errors.any?).to be false
      end
    end

    describe '#create_#{relation}!' do
      it 'should pass through any exceptions' do
        mainframes_link.stub(:create) { raise hyperresource_exception }
        expect do
          subject.create_mainframe!({})
        end.to raise_error HyperResource::ResponseError
      end

      it 'should return the object in the event of successful creation' do
        mainframes_link.stub(:create) { mainframe }
        expect(subject.create_mainframe!({})).to eq mainframe
      end
    end

    describe '#{relation}s' do
      include_context 'paginated collection'

      it 'should return all records' do
        records = subject.mainframes

        expect(records.size).to eq(2)
        expect(records.first).to eq('At /mainframes')
        expect(records.second).to eq('At /mainframes?page=1')
        expect(calls).to eq(urls)
      end
    end

    describe 'each_#{relation}' do
      include_context 'paginated collection'

      it 'should iterate over all records' do
        records = []
        subject.each_mainframe { |mainframe| records << mainframe }

        expect(records.size).to eq(2)
        expect(records.first).to eq('At /mainframes')
        expect(records.second).to eq('At /mainframes?page=1')
        expect(calls).to eq(urls)
      end

      it 'should stop iterating when the consumer breaks' do
        subject.each_mainframe { |_| break }
        expect(calls).to eq([urls[0]])
      end

      it 'should return an enum if no block is given' do
        e = subject.each_mainframe
        records = []
        e.each { |m| records << m }
        expect(records.size).to eq(2)
        expect(calls).to eq(urls)
      end
    end
  end

  context '.embeds_many' do
    let(:m1) { Api::Mainframe.new }
    let(:m2) { Api::Mainframe.new }

    before { subject.stub(:loaded) { true } }
    before { subject.stub(:objects) { { embedded_mainframes: [m1, m2] } } }
    before { m1.stub(id: 1) }
    before { m2.stub(id: 2) }

    describe '#{relation}s' do
      it 'should return all records' do
        records = subject.embedded_mainframes

        expect(records.size).to eq(2)
        expect(records.first.id).to eq(1)
        expect(records.second.id).to eq(2)
      end
    end

    describe 'each_#{relation}' do
      it 'should iterate over all records' do
        records = []
        subject.each_embedded_mainframe { |mainframe| records << mainframe }

        expect(records.size).to eq(2)
        expect(records.first.id).to eq(1)
        expect(records.second.id).to eq(2)
      end

      it 'should return an enum if no block is given' do
        e = subject.each_embedded_mainframe
        records = []
        e.each { |mainframe| records << mainframe }

        expect(records.size).to eq(2)
        expect(records.first.id).to eq(1)
        expect(records.second.id).to eq(2)
      end
    end
  end

  context '.field' do
    it 'should define a method for the field' do
      Api.field :foo, type: String
      expect(subject.respond_to?(:foo)).to be true
    end

    it 'should return the raw attribute' do
      Api.field :foo, type: String
      subject.stub(:attributes) { { foo: 'bar' } }
      expect(subject.foo).to eq 'bar'
    end

    it 'should parse the attribute if DateTime' do
      Api.field :created_at, type: DateTime
      subject.stub(:attributes) { { created_at: Time.now.to_json } }
      expect(subject.created_at).to be_a DateTime
    end

    it 'should parse the attribute if Time' do
      Api.field :created_at, type: Time
      subject.stub(:attributes) { { created_at: Time.now.to_json } }
      expect(subject.created_at).to be_a Time
    end

    it 'should add a ? helper if Boolean' do
      Api.field :awesome, type: Aptible::Resource::Boolean
      subject.stub(:attributes) { { awesome: 'true' } }
      expect(subject.awesome?).to be true
    end
  end

  context 'configuration' do
    subject { Api.new(root: 'http://example.com') }

    def configure_new_coordinator(&block)
      Aptible::Resource.configure do |config|
        config.retry_coordinator_class = \
          Class.new(Aptible::Resource::DefaultRetryCoordinator) do
            instance_exec(&block)
          end
      end
    end

    context 'retry_coordinator_class' do
      it 'should not retry if the proc returns false' do
        configure_new_coordinator { define_method(:retry?) { |_, _e| false } }

        stub_request(:get, 'example.com')
          .to_return(body: { error: 'foo' }.to_json, status: 401).then
          .to_return(body: { status: 'ok' }.to_json, status: 200)

        expect { subject.get.body }
          .to raise_error(HyperResource::ClientError, /foo/)
      end

      it 'should retry if the proc returns true' do
        configure_new_coordinator { define_method(:retry?) { |_, _e| true } }

        stub_request(:get, 'example.com')
          .to_return(body: { error: 'foo' }.to_json, status: 401).then
          .to_return(body: { error: 'foo' }.to_json, status: 401).then
          .to_return(body: { status: 'ok' }.to_json, status: 200)

        expect(subject.get.body).to eq('status' => 'ok')
      end

      it 'should not retry if the request succeeds' do
        failures = 0

        configure_new_coordinator do
          define_method(:retry?) { |_, _e| failures += 1 || true }
        end

        stub_request(:get, 'example.com')
          .to_return(body: { error: 'foo' }.to_json, status: 401).then
          .to_return(body: { status: 'ok' }.to_json, status: 200).then
          .to_return(body: { error: 'foo' }.to_json, status: 401)

        expect(subject.get.body).to eq('status' => 'ok')

        expect(failures).to eq(1)
      end

      it 'should not retry with the default proc' do
        stub_request(:get, 'example.com')
          .to_return(body: { error: 'foo' }.to_json, status: 401).then
          .to_return(body: { status: 'ok' }.to_json, status: 200)

        expect { subject.get.body }
          .to raise_error(HyperResource::ClientError, /foo/)
      end

      it 'should pass the resource in constructor and exception in method' do
        resource = nil
        exception = nil

        configure_new_coordinator do
          define_method(:initialize) { |r| resource = r }
          define_method(:retry?) { |_, e| (exception = e) && false }
        end

        stub_request(:get, 'example.com')
          .to_return(body: { error: 'foo' }.to_json, status: 401)

        expect { subject.get.body }
          .to raise_error(HyperResource::ClientError, /foo/)

        expect(resource).to be_a(Api)
        expect(exception).to be_a(HyperResource::ClientError)
      end

      it 'should let the coordinator change e.g. the request token' do
        subject.token = 'foo'
        retry_was_called = false

        configure_new_coordinator do
          define_method(:retry?) do |_, _e|
            resource.token = 'bar'
            # resource.headers['Authorization'] = 'Bearer bar'
            retry_was_called = true
          end
        end

        stub_request(:get, 'example.com')
          .with(headers: { 'Authorization' => /foo/ })
          .to_return(body: { error: 'foo' }.to_json, status: 401)

        stub_request(:get, 'example.com')
          .with(headers: { 'Authorization' => /bar/ })
          .to_return(body: { status: 'ok' }.to_json, status: 200)

        expect(subject.get.body).to eq('status' => 'ok')
        expect(retry_was_called).to be_truthy
      end

      it 'should eventually fail even if the coordinator wants to retry' do
        n = 0

        configure_new_coordinator do
          define_method(:retry?) { |_, _e| n += 1 || true }
        end

        stub_request(:get, 'example.com')
          .to_return(body: { error: 'foo' }.to_json, status: 401)

        expect { subject.get.body }
          .to raise_error(HyperResource::ClientError, /foo/)

        expect(n).to eq(HyperResource::Modules::HTTP::MAX_COORDINATOR_RETRIES)
      end
    end

    context 'user_agent' do
      it 'should update the user agent' do
        Aptible::Resource.configure do |config|
          config.user_agent = 'foo ua'
        end

        stub_request(:get, 'example.com')
          .with(headers: { 'User-Agent' => 'foo ua' })
          .to_return(body: { status: 'ok' }.to_json, status: 200)

        expect(subject.get.body).to eq('status' => 'ok')
      end
    end
  end

  context 'token' do
    subject { Api.new(root: 'http://example.com', token: 'bar') }

    before do
      stub_request(:get, 'example.com/')
        .with(headers: { 'Authorization' => /Bearer (bar|foo)/ })
        .to_return(body: {
          _links: { some: { href: 'http://example.com/some' },
                    mainframes: { href: 'http://example.com/mainframes' } },
          _embedded: { best_mainframe: { _type: 'mainframe', status: 'ok' } }
        }.to_json, status: 200)

      stub_request(:get, 'example.com/some')
        .with(headers: { 'Authorization' => /Bearer (bar|foo)/ })
        .to_return(body: { status: 'ok' }.to_json, status: 200)

      stub_request(:get, 'example.com/mainframes')
        .with(headers: { 'Authorization' => /Bearer (bar|foo)/ })
        .to_return(body: { _embedded: {
          mainframes: [{ status: 'ok' }]
        } }.to_json, status: 200)
    end

    it 'should persist the Authorization header when following links' do
      expect(subject.some.get.body).to eq('status' => 'ok')
    end

    it 'should persist the token when following links' do
      expect(subject.some.token).to eq('bar')
      expect(subject.some.headers['Authorization']).to eq('Bearer bar')
    end

    it 'should set the Authorization header when setting the token' do
      subject.token = 'foo'

      expect(subject.some.token).to eq('foo')
      expect(subject.some.headers['Authorization']).to eq('Bearer foo')
    end

    it 'should persist the token and set the Authorization header when ' \
       'initializing from resource' do
      subject.get
      r = Api.new(subject)

      expect(r.token).to eq('bar')
      expect(r.headers['Authorization']).to eq('Bearer bar')
    end

    it 'should persist the token when accessing a related collection' do
      m = subject.mainframes.first
      expect(m.token).to eq('bar')
    end

    it 'should persist the token when accessing a named embedded object' do
      m = subject.best_mainframe
      expect(m.token).to eq('bar')
    end
  end

  context 'lazy fetching' do
    subject { Api.new(root: 'http://foo.com') }

    it 'should support enumerable methods' do
      index = {
        _links: {
          some_items: { href: 'http://foo.com/some_items' }
        }
      }

      some_items = {
        _embedded: {
          some_items: [
            { id: 1, handle: 'foo' },
            { id: 2, handle: 'bar' },
            { id: 3, handle: 'qux' }
          ]
        }
      }

      stub_request(:get, 'foo.com')
        .to_return(body: index.to_json, status: 200)

      stub_request(:get, 'foo.com/some_items')
        .to_return(body: some_items.to_json, status: 200)

      bar = subject.some_items.find { |m| m.id == 2 }
      expect(bar.handle).to eq('bar')
    end
  end

  describe '_type' do
    subject { Api.new(root: 'http://example.com', token: 'bar') }

    it 'uses the correct class for an expected linked instance' do
      stub_request(:get, 'example.com/')
        .to_return(body: {
          _links: {
            worst_mainframe: { href: 'http://example.com/mainframes/123' }
          }
        }.to_json, status: 200)

      stub_request(:get, 'example.com/mainframes/123')
        .to_return(body: { _type: 'mainframe', id: 123 }.to_json, status: 200)

      expect(subject.worst_mainframe).to be_a(Api::Mainframe)
    end

    it 'uses the correct class for an unexpected linked instance' do
      stub_request(:get, 'example.com/')
        .to_return(body: {
          _links: {
            some: { href: 'http://example.com/mainframes/123' }
          }
        }.to_json, status: 200)

      stub_request(:get, 'example.com/mainframes/123')
        .to_return(body: { _type: 'mainframe', id: 123 }.to_json, status: 200)

      expect(subject.some.get).to be_a(Api::Mainframe)
    end

    it 'uses the correct class for an expected embedded instance' do
      stub_request(:get, 'example.com/')
        .to_return(body: {
          _embedded: { best_mainframe: { _type: 'mainframe', id: 123 } }
        }.to_json, status: 200)

      expect(subject.best_mainframe).to be_a(Api::Mainframe)
    end

    it 'uses the correct class for an unexpected embedded instance' do
      stub_request(:get, 'example.com/')
        .to_return(body: {
          _embedded: { some: { _type: 'mainframe', id: 123 } }
        }.to_json, status: 200)

      expect(subject.some).to be_a(Api::Mainframe)
    end
  end
end
