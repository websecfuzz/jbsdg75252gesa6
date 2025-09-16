# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::NamespaceLimitMailer, feature_category: :consumables_cost_management do
  include NamespacesHelper
  include EmailSpec::Matchers

  let(:recipients) { %w[bob@example.com john@example.com] }
  let(:namespace) { build_stubbed(:namespace) }
  let(:usage_quotas_link) do
    ActionController::Base.helpers.link_to(namespace.name, usage_quotas_url(namespace, anchor: 'storage-quota-tab'))
  end

  describe '#notify_out_of_storage' do
    it 'creates an email message for a namespace', :aggregate_failures do
      mail = described_class.notify_out_of_storage(namespace: namespace, recipients: recipients,
        usage_values: {
          current_size: 101.megabytes,
          limit: 100.megabytes,
          usage_ratio: 1.01
        })

      expect(mail).to have_subject "Action required: Storage has been exceeded for #{namespace.name}"
      expect(mail).to bcc_to recipients
      expect(mail).to have_body_text(
        "You have used 101% of the storage quota for #{usage_quotas_link} (101 MiB of 100 MiB)"
      )
      expect(mail).to have_body_text buy_storage_url(namespace)
    end
  end

  describe '#notify_limit_warning' do
    it 'creates an email message for a namespace', :aggregate_failures do
      mail = described_class.notify_limit_warning(namespace: namespace, recipients: recipients,
        usage_values: {
          current_size: 75.megabytes,
          limit: 100.megabytes,
          usage_ratio: 0.75
        })

      expect(mail).to have_subject "You have used 75% of the storage quota for #{namespace.name}"
      expect(mail).to bcc_to recipients
      expect(mail).to have_body_text(
        "You have used 75% of the storage quota for #{usage_quotas_link} (75 MiB of 100 MiB)"
      )
      expect(mail).to have_body_text buy_storage_url(namespace)
    end
  end
end
