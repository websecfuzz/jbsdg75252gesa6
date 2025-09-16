# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::NamespaceStorageSizeErrorMessage, :saas, feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers

  let_it_be(:namespace) { create(:namespace_with_plan, plan: :ultimate_plan) }
  let_it_be(:root_storage_statistics) { create(:namespace_root_storage_statistics, namespace: namespace) }

  let(:size_checker) { Namespaces::Storage::RootSize.new(namespace) }
  let(:message_params) { { namespace_name: namespace.name } }
  let(:error_message) { described_class.new(checker: size_checker, message_params: message_params) }

  before do
    set_enforcement_limit(namespace, megabytes: 10)
    set_used_storage(namespace, megabytes: 12)
  end

  describe '#commit_error' do
    it 'returns the expected message' do
      expected_message = "Your action has been rejected because the namespace storage limit has been reached. " \
                         "For more information, visit " \
                         "#{Rails.application.routes.url_helpers.help_page_url('user/storage_usage_quotas.md')}."

      expect(error_message.commit_error).to eq(expected_message)
    end
  end

  describe '#merge_error' do
    it 'returns the expected message' do
      expected_message = 'Your namespace storage is full. ' \
                         'This merge request cannot be merged.'

      expect(error_message.merge_error).to eq(expected_message)
    end
  end

  describe 'push error messages' do
    let(:usage_quotas_guide) do
      ::Gitlab::Routing.url_helpers.help_page_url('user/storage_usage_quotas.md', anchor: 'manage-storage-usage')
    end

    let(:read_only_namespaces_guide) do
      ::Gitlab::Routing.url_helpers.help_page_url('user/read_only_namespaces.md', anchor: 'restricted-actions')
    end

    describe '#push_error' do
      it 'returns the expected message' do
        expected_message = "##### ERROR ##### You have used 120% of the storage quota for " \
                           "#{namespace.name} (12 MiB of 10 MiB). #{namespace.name} is now read-only. " \
                           "Projects under this namespace are locked and actions will be restricted. " \
                           "To manage storage, or purchase additional storage, " \
                           "see #{usage_quotas_guide}. " \
                           "To learn more about restricted actions, " \
                           "see #{read_only_namespaces_guide}"

        expect(error_message.push_error).to eq(expected_message)
      end
    end

    describe '#new_changes_error' do
      it 'returns the expected message' do
        expected_message = "Your push to this repository has been rejected because " \
                           "it would exceed the namespace storage limit of 10 MiB. " \
                           "Reduce your namespace storage or purchase additional storage." \
                           "To manage storage, or purchase additional storage, " \
                           "see #{usage_quotas_guide}. " \
                           "To learn more about restricted actions, " \
                           "see #{read_only_namespaces_guide}"

        expect(error_message.new_changes_error).to eq(expected_message)
      end
    end

    describe '#above_size_limit_message' do
      it 'returns the expected message' do
        expected_message = "The namespace storage size (12 MiB) exceeds the limit of 10 MiB " \
                           "by 2 MiB. You won't be able to push new code to this project. " \
                           "Please contact your GitLab administrator for more information."

        expect(error_message.above_size_limit_message).to eq(expected_message)
      end
    end
  end
end
