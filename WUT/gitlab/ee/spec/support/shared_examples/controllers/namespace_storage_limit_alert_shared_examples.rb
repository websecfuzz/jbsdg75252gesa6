# frozen_string_literal: true

RSpec.shared_examples 'namespace storage limit alert' do
  include NamespaceStorageHelpers

  let(:alert_level) { :info }

  before do
    enforce_namespace_storage_limit(namespace)

    allow_next_instance_of(Namespaces::Storage::NamespaceLimit::AlertComponent) do |alert_component|
      allow(alert_component).to receive(:alert_title).and_return("Alert Title")
      allow(alert_component).to receive(:alert_message).and_return(["Alert Message"])
    end

    allow_next_instance_of(Namespaces::Storage::RootSize) do |size_checker|
      allow(size_checker).to receive(:usage_ratio).and_return(0.75)
    end

    allow(controller).to receive(:current_user).and_return(user) if controller

    namespace.add_owner(user)
  end

  it 'does render' do
    subject

    expect(response.body).to match(/Alert Title/)
    expect(response.body).to match(/Alert Message/)
    expect(response.body).to have_css('.js-namespace-storage-alert')
  end

  context 'when user has dismissed already' do
    before do
      allow(user).to receive(:dismissed_callout?).and_return(true)
      allow(user).to receive(:dismissed_callout_for_group?).and_return(true)
    end

    it 'does not render alert' do
      subject

      expect(response.body).not_to match(/Alert Title/)
      expect(response.body).not_to have_css('.js-namespace-storage-alert')
    end
  end
end
