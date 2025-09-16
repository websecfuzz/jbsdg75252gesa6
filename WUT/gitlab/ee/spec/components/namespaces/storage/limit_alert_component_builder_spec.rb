# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Storage::LimitAlertComponentBuilder, :saas, feature_category: :consumables_cost_management do
  let(:gitlab_subscription) { build_stubbed(:gitlab_subscription) }
  let(:group) do
    build_stubbed(
      :group,
      gitlab_subscription: gitlab_subscription
    )
  end

  subject(:component) { described_class.build(context: group, user: nil) }

  describe '#build' do
    include NamespaceStorageHelpers

    context 'when namespace limit is enforced' do
      before do
        enforce_namespace_storage_limit(group)
      end

      it 'builds a NamespaceLimit::AlertComponent' do
        is_expected.to be_instance_of(Namespaces::Storage::NamespaceLimit::AlertComponent)
      end
    end

    context 'when repository limit is enforced' do
      it 'builds a RepositoryLimit::AlertComponent' do
        is_expected.to be_instance_of(Namespaces::Storage::RepositoryLimit::AlertComponent)
      end
    end
  end
end
