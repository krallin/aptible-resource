require 'spec_helper'

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
end
