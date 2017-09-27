require 'spec_helper'

describe Aptible::Resource::Base do
  it 'throws errors with a useful message' do
    href = 'https://resource.example.com/mainframes/1'
    body = { 'error' => 'unprocessable_entity', message: 'This is all wrong' }
    stub_request(:get, href).to_return(body: JSON.unparse(body), status: 422)

    expect { Api::Mainframe.find(1) }
      .to raise_error(/unprocessable_entity.*all wrong/im)
  end
end
