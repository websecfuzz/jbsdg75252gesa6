# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::LdapEncryptedSecretsMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  let(:encrypted_config) { instance_double(Gitlab::EncryptedConfiguration) }

  where(:ldap_encrypted_secrets_enabled, :expected_value) do
    true  | true
    false | false
  end

  with_them do
    before do
      allow(Gitlab::Auth::Ldap::Config).to receive(:encrypted_secrets).and_return(encrypted_config)
      allow(encrypted_config).to receive(:active?).and_return(ldap_encrypted_secrets_enabled)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
