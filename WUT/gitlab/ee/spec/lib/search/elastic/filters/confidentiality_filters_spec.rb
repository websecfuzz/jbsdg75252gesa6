# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters::ConfidentialityFilters, feature_category: :global_search do
  include_context 'with filters shared context'
  let_it_be_with_reload(:user) { create(:user) }

  let(:test_klass) do
    Class.new do
      include Search::Elastic::Filters::ConfidentialityFilters
    end
  end

  let(:expected_query) do
    json = File.read(Rails.root.join(fixtures_path, fixture_file))
    # the traversal_id for the group the user has access to
    json.gsub!('__NAMESPACE_ANCESTRY__', namespace_ancestry) if defined?(namespace_ancestry)
    # the traversal_id for the shared group the user has access to
    json.gsub!('__SHARED_NAMESPACE_ANCESTRY__', shared_namespace_ancestry) if defined?(shared_namespace_ancestry)
    # the id for the group the user has access to
    json.gsub!('__NAMESPACE_ID__', namespace_id.to_s) if defined?(namespace_id)
    # the traversal_id for the shared group the user has access to
    json.gsub!('__SHARED_NAMESPACE_ID__', shared_namespace_id.to_s) if defined?(shared_namespace_id)
    # the id for the project the user has access to
    json.gsub!('__PROJECT_ID__', project_id.to_s) if defined?(project_id)
    # the id for the user
    json.gsub!('__USER_ID__', user_id.to_s) if defined?(user_id)

    ::Gitlab::Json.parse(json).deep_symbolize_keys
  end

  describe '.by_group_level_confidentiality' do
    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_group_level_confidentiality' }

    let(:base_options) do
      {
        current_user: user,
        search_level: 'global',
        min_access_level_non_confidential: ::Gitlab::Access::GUEST,
        min_access_level_confidential: ::Gitlab::Access::PLANNER
      }
    end

    let(:options) { base_options }

    subject(:by_group_level_confidentiality) do
      test_klass.by_group_level_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when user.can_read_all_resources? is true' do
      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when user has the role set in option :min_access_level_confidential for group' do
      context 'for a top level group' do
        let(:fixture_file) { 'global_search_user_access_to_group_with_confidential_access.json' }

        let_it_be(:group) { create(:group, :private, planners: user) }
        let(:namespace_ancestry) { group.elastic_namespace_ancestry }

        it { is_expected.to eq(expected_query) }
      end

      context 'for a sub group' do
        let(:fixture_file) { 'global_search_user_access_to_group_with_confidential_access.json' }

        let_it_be(:parent_group) { create(:group, :private) }
        let_it_be(:group) { create(:group, :private, parent: parent_group, planners: user) }
        let(:namespace_ancestry) { group.elastic_namespace_ancestry }

        it { is_expected.to eq(expected_query) }
      end

      context 'for group through shared group permission' do
        let(:fixture_file) { 'global_search_user_access_to_group_through_shared_group_with_confidential_access.json' }

        let_it_be(:shared_group) { create(:group, :private, planners: user) }
        let_it_be(:group) { create(:group) }
        let_it_be(:group_link) do
          create(:group_group_link, :planner, shared_group: group, shared_with_group: shared_group)
        end

        let(:shared_namespace_ancestry) { shared_group.elastic_namespace_ancestry }
        let(:namespace_ancestry) { group.elastic_namespace_ancestry }

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'when current_user is nil' do
      let(:fixture_file) { 'global_search_anonymous_user.json' }
      let(:options) { base_options.merge(current_user: nil) }

      it { is_expected.to eq(expected_query) }
    end

    context 'when current_user does not have any role which allows private group access' do
      let(:fixture_file) { 'global_search_user_no_access.json' }

      it { is_expected.to eq(expected_query) }

      context 'and user is external' do
        let(:fixture_file) { 'global_search_external_user.json' }

        before do
          allow(user).to receive(:external?).and_return(true)
        end

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'when user has the role set in option :min_access_level_non_confidential for group' do
      let(:fixture_file) { 'global_search_user_access_to_group_with_non_confidential_access.json' }
      let_it_be(:group) { create(:group, :private, guests: user) }
      let(:namespace_ancestry) { group.elastic_namespace_ancestry }

      it { is_expected.to eq(expected_query) }
    end

    context 'when user has GUEST permission for a project in the group hierarchy' do
      let(:fixture_file) { 'global_search_user_access_to_project_with_non_confidential_access.json' }

      let_it_be(:group) { create(:group, :private) }
      let_it_be(:sub_group) { create(:group, :private, parent: group) }
      let_it_be(:project) { create(:project, :private, group: sub_group, guests: user) }
      let(:namespace_id) { group.id }
      let(:shared_namespace_id) { sub_group.id }

      it { is_expected.to eq(expected_query) }

      context 'and user also has GUEST permission to the top level group' do
        let(:fixture_file) { 'global_search_user_access_to_group_and_project_with_non_confidential_access.json' }
        let(:namespace_ancestry) { group.elastic_namespace_ancestry }

        before_all do
          group.add_guest(user)
        end

        it { is_expected.to eq(expected_query) }
      end
    end
  end

  describe '.by_project_confidentiality' do
    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_project_level_confidentiality' }

    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let_it_be(:private_project) { create(:project, :private) }

    subject(:by_project_confidentiality) do
      test_klass.by_project_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when options[:confidential] is not passed or not true/false' do
      let(:base_options) { { current_user: user } }
      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:fixture_file) { 'global_search_user_access_to_project_with_confidential_access_non_confidential.json' }
        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }
        let(:project_id) { authorized_project.id }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:fixture_file) { 'global_search_user_access_to_project_with_confidential_access_non_confidential.json' }
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }
        let(:project_id) { authorized_project.id }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }
      end

      context 'when options[:current_user] is empty' do
        let(:fixture_file) { 'global_search_anonymous_user.json' }
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'when options[:confidential] is passed' do
      let(:base_options) { { current_user: user, confidential: true } }
      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        let(:fixture_file) { 'global_search_admin_user.json' }

        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it { is_expected.to eq(expected_query) }
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:fixture_file) { 'global_search_user_access_to_project_with_confidential_access_confidential.json' }

        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }
        let(:project_id) { authorized_project.id }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:fixture_file) { 'global_search_user_access_to_project_with_confidential_access_confidential.json' }
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }
        let(:project_id) { authorized_project.id }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }
      end

      context 'when options[:current_user] is empty' do
        let(:fixture_file) { 'global_search_anonymous_user.json' }
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it { is_expected.to eq(expected_query) }
      end
    end
  end
end
