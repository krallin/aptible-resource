require 'spec_helper'
require 'fixtures/api'
require 'fixtures/mainframe'
require 'fixtures/token'

describe Aptible::Resource::Base do
  subject { Api.new }

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
      token.stub(:access_token) { 'abtible_auth_token' }
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
  end

  describe '.all' do
    let(:mainframe) { double 'Mainframe' }
    let(:collection) { double 'Api' }

    before do
      collection.stub(:mainframes) { [mainframe] }
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

  describe '.create' do
    it 'should create a new top-level resource' do
      mainframes = double 'Api'
      Api.stub_chain(:new, :mainframes) { mainframes }
      expect(mainframes).to receive(:create).with(foo: 'bar')
      Api::Mainframe.create(foo: 'bar')
    end
  end
end
