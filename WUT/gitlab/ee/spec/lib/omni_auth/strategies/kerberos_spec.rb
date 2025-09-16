# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::Kerberos, feature_category: :system_access do
  subject { described_class.new(:app) }

  let(:session) { {} }

  before do
    allow(subject).to receive(:session).and_return(session)
  end

  it 'uses the principal name as the "uid"' do
    session[:kerberos_principal_name] = 'Janedoe@FOOBAR.COM'
    expect(subject.uid).to eq('Janedoe@FOOBAR.COM')
  end

  it 'extracts the username' do
    session[:kerberos_principal_name] = 'Janedoe@FOOBAR.COM'
    expect(subject.username).to eq('Janedoe')
  end

  it 'turns the principal name into an email address' do
    session[:kerberos_principal_name] = 'Janedoe@FOOBAR.COM'
    expect(subject.email).to eq('Janedoe@foobar.com')
  end

  it 'clears its special session key' do
    session[:kerberos_principal_name] = 'Janedoe@FOOBAR.COM'
    subject.username
    expect(session).to eq({})
  end
end
