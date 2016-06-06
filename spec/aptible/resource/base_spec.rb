require 'spec_helper'

describe Aptible::Resource::Base do
  let(:hyperresource_exception) { HyperResource::ResponseError.new('403') }
  let(:error_response) { double 'Faraday::Response' }
  before { hyperresource_exception.stub(:response) { error_response } }
  before do
    error_response.stub(:body) { { message: 'Forbidden' }.to_json }
    error_response.stub(:status) { 403 }
  end

  subject { Api.new }

  describe '.collection_href' do
    it 'should use the pluralized resource name' do
      url = Api::Mainframe.collection_href
      expect(url).to eq '/mainframes'
    end
  end

  describe '.find' do
    it 'should call find_by_url' do
      url = '/mainframes/42'
      expect(Api::Mainframe).to receive(:find_by_url).with url, {}
      Api::Mainframe.find(42)
    end

    it 'should call find_by_url with query params' do
      url = '/mainframes/42?test=123'
      expect(Api::Mainframe).to receive(:find_by_url).with url, test: 123
      Api::Mainframe.find(42, test: 123)
    end
  end

  describe '.all' do
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

    context 'when paginated' do
      before do
        page = double('page')
        allow(page).to receive(:href).and_return(
          '/next/page', '/next/page', '/next/page'
        )
        allow(collection).to receive(:links).and_return(
          { 'next' => page }, { 'next' => page }, {}
        )
      end

      it 'should collect entries on all pages' do
        expect(Api::Mainframe.all).to eq [mainframe] + [mainframe]
      end
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
      mainframes_link.stub(:create) { fail hyperresource_exception }
      mainframe = Api::Mainframe.create
      expect(mainframe.errors.messages).to eq(base: 'Forbidden')
      expect(mainframe.errors.full_messages).to eq(['Forbidden'])
    end

    it 'should return a Base-classed resource on error' do
      mainframes_link.stub(:create) { fail hyperresource_exception }
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
      mainframes_link.stub(:create) { fail hyperresource_exception }
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
      expect { described_class.new }
        .to raise_error(/by subclass.*Aptible::Resource::Base/)
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
      HyperResource.any_instance.stub(:put) { fail hyperresource_exception }
      subject.update({})
      expect(subject.errors.messages).to eq(base: 'Forbidden')
      expect(subject.errors.full_messages).to eq(['Forbidden'])
    end

    it 'should return false in the event of an error' do
      HyperResource.any_instance.stub(:put) { fail hyperresource_exception }
      expect(subject.update({})).to eq false
    end

    it 'should return the object in the event of a successful update' do
      HyperResource.any_instance.stub(:put) { subject }
      expect(subject.update({})).to eq subject
    end
  end

  describe '#update!' do
    it 'should populate #errors in the event of an error' do
      HyperResource.any_instance.stub(:put) { fail hyperresource_exception }
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
      HyperResource.any_instance.stub(:put) { fail hyperresource_exception }
      expect do
        subject.update!({})
      end.to raise_error HyperResource::ResponseError
    end

    it 'should return the object in the event of a successful update' do
      HyperResource.any_instance.stub(:put) { subject }
      expect(subject.update!({})).to eq subject
    end
  end

  context '.has_many' do
    let(:mainframe) { Api::Mainframe.new }
    let(:mainframes_link) { HyperResource::Link.new(href: '/mainframes') }

    before { Api.has_many :mainframes }
    before { subject.stub(:loaded) { true } }
    before { subject.stub(:links) { { mainframes: mainframes_link } } }
    before { mainframes_link.stub(:entries) { [mainframe] } }
    before { mainframes_link.stub(:base_href) { '/mainframes' } }

    describe '#create_#{relation}' do
      it 'should populate #errors in the event of an error' do
        mainframes_link.stub(:create) { fail hyperresource_exception }
        mainframe = subject.create_mainframe({})
        expect(mainframe.errors.messages).to eq(base: 'Forbidden')
        expect(mainframe.errors.full_messages).to eq(['Forbidden'])
      end

      it 'should return a Base-classed resource on error' do
        mainframes_link.stub(:create) { fail hyperresource_exception }
        expect(subject.create_mainframe.class).to eq Aptible::Resource::Base
      end

      it 'should have errors present on error' do
        mainframes_link.stub(:create) { fail hyperresource_exception }
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
        mainframes_link.stub(:create) { fail hyperresource_exception }
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
      it 'should defer to self.class.all' do
        expect(subject.class).to receive(:all).with(href: '/mainframes',
                                                    headers: subject.headers)
        subject.mainframes
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
end
