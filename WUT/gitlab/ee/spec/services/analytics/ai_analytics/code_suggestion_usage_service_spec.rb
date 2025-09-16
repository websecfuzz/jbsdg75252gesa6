# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::CodeSuggestionUsageService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(
      current_user,
      namespace: container,
      from: from,
      to: to,
      languages: languages
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:project_namespace) { project.reload.project_namespace }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: subgroup) }
  let_it_be(:user3) { create(:user, developer_of: group) }
  let_it_be(:not_member) { create(:user) }
  let(:languages) { [] }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common ai usage rate service' do |flag_enabled|
    # This shared examples requires the following variables
    # :expected_results
    # :expected_language_filtered_results

    before do
      stub_feature_flags(fetch_contributions_data_from_new_tables: flag_enabled)
    end

    context 'when the clickhouse is not available for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns service error' do
        expect(service_response).to be_error

        message = s_('AiAnalytics|the ClickHouse data store is not available')
        expect(service_response.message).to eq(message)
      end
    end

    context 'when the feature is available', :click_house, :freeze_time do
      let(:from) { 14.days.ago }
      let(:to) { 1.day.ago }

      context 'without data' do
        it 'returns 0' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({
            code_contributors_count: 0,
            code_suggestions_contributors_count: 0,
            code_suggestions_accepted_count: 0,
            code_suggestions_shown_count: 0,
            # New fields
            accepted_count: 0,
            accepted_lines_of_code: 0,
            contributors_count: 0,
            languages: [],
            shown_count: 0,
            shown_lines_of_code: 0
          })
        end
      end

      context 'with only few fields selected' do
        it 'returns only selected fields' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: %i[code_contributors_count foo]).execute

          expect(response.payload).to match(code_contributors_count: 0)
        end
      end

      context 'with no selected fields' do
        it 'returns empty stats hash' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: []).execute

          expect(response).to be_success
          expect(response.payload).to eq({})
        end
      end

      context 'with data' do
        before do
          clickhouse_fixture(:code_suggestion_events, [
            # shown
            { user_id: user1.id, namespace_path: group.traversal_path, event: 2, language: 'ruby',
              suggestion_size: 10, timestamp: to - 3.days },
            # accepted
            { user_id: user1.id, namespace_path: project_namespace.traversal_path, event: 3, language: 'ruby',
              suggestion_size: 20, timestamp: to - 3.days + 1.second },
            # shown
            { user_id: user1.id, namespace_path: project_namespace.traversal_path, event: 2, language: 'ruby',
              suggestion_size: 30, timestamp: to - 4.days },
            # shown
            { user_id: user2.id, namespace_path: subgroup.traversal_path, event: 2, language: 'js',
              suggestion_size: 40, timestamp: to - 2.days },
            # shown
            { user_id: user2.id, namespace_path: project_namespace.traversal_path, event: 2, language: 'rust',
              suggestion_size: 50, timestamp: to - 2.days },
            # shown
            # these are taken into account when fetch_contributions_data_from_new_tables is enabled
            { user_id: not_member.id, namespace_path: group.traversal_path, language: 'c++', suggestion_size: 60,
              event: 2, timestamp: to - 2.days },
            # accepted
            # these are taken into account when fetch_contributions_data_from_new_tables is enabled
            { user_id: not_member.id, namespace_path: group.traversal_path, language: 'c', suggestion_size: 70,
              event: 3, timestamp: to - 2.days + 1.second },
            # shown
            # Out of timeframe
            { user_id: user3.id, namespace_path: project_namespace.traversal_path, event: 2, language: 'perl',
              suggestion_size: 80, timestamp: to + 2.days },
            # shown
            # Out of timeframe
            { user_id: user3.id, namespace_path: subgroup.traversal_path, event: 2, language: 'php',
              suggestion_size: 90, timestamp: from - 2.days }
          ])

          insert_events_into_click_house([
            build_stubbed(:event, :pushed, project: project, author: user1, created_at: to - 1.day),
            build_stubbed(:event, :pushed, project: project, author: user1, created_at: to - 2.days),
            build_stubbed(:event, :pushed, project: project, author: user2, created_at: to - 1.day),
            build_stubbed(:event, :pushed, project: project, author: user3, created_at: to - 1.day)
          ])
        end

        it 'returns matched code contributors AI usage stats' do
          expect(service_response).to be_success
          expect(service_response.payload).to match(expected_results)
        end

        context 'when using languages filter' do
          let(:languages) { %w[js rust] }

          it 'returns metrics filtered by languages used' do
            expect(service_response.payload).to match(expected_language_filtered_results)
          end
        end
      end
    end
  end

  context 'when use_ai_events_namespace_path_filter feature flag is disabled' do
    let(:expected_results) do
      {
        code_contributors_count: 3,
        code_suggestions_contributors_count: 2,
        code_suggestions_accepted_count: 1,
        code_suggestions_shown_count: 4,
        # New fields
        contributors_count: 2,
        shown_count: 4,
        accepted_count: 1,
        languages: %w[js rust ruby],
        shown_lines_of_code: 130,
        accepted_lines_of_code: 20
      }
    end

    let(:expected_language_filtered_results) do
      {
        # Legacy fields do not support languages filter
        code_contributors_count: 3,
        code_suggestions_contributors_count: 2,
        code_suggestions_accepted_count: 1,
        code_suggestions_shown_count: 4,
        # Fields filtered by languages
        contributors_count: 1,
        shown_count: 2,
        accepted_count: 0,
        languages: %w[js rust],
        shown_lines_of_code: 90,
        accepted_lines_of_code: 0
      }
    end

    before do
      stub_feature_flags(use_ai_events_namespace_path_filter: false)
    end

    context 'for group' do
      let_it_be(:container) { group }

      it_behaves_like 'common ai usage rate service', true

      context 'when fetch_contributions_data_from_new_tables feature flag is disabled' do
        it_behaves_like 'common ai usage rate service', false
      end
    end

    context 'for project' do
      let_it_be(:container) { project.project_namespace.reload }

      it_behaves_like 'common ai usage rate service', true

      context 'when fetch_contributions_data_from_new_tables feature flag is disabled' do
        it_behaves_like 'common ai usage rate service', false
      end
    end
  end

  context 'when use_ai_events_namespace_path_filter feature flag is enabled' do
    context 'for group' do
      let_it_be(:container) { group }

      let(:expected_results) do
        {
          # Legacy fields
          contributors_count: 3,
          code_contributors_count: 3,
          code_suggestions_contributors_count: 3,
          code_suggestions_accepted_count: 2,
          code_suggestions_shown_count: 5,
          # New fields
          shown_count: 5,
          accepted_count: 2,
          languages: ["c", "js", "c++", "rust", "ruby"],
          shown_lines_of_code: 190,
          accepted_lines_of_code: 90
        }
      end

      let(:expected_language_filtered_results) do
        {
          # Legacy fields do not support languages filter,
          code_contributors_count: 3,
          code_suggestions_contributors_count: 3,
          code_suggestions_accepted_count: 2,
          code_suggestions_shown_count: 5,
          # Fields filtered by languages
          contributors_count: 1,
          shown_count: 2,
          accepted_count: 0,
          languages: %w[js rust],
          shown_lines_of_code: 90,
          accepted_lines_of_code: 0
        }
      end

      # When use_ai_events_namespace_path_filter is enabled we do not need to
      # run this shared behavior with 'true' parameter because contributors filter won't be used
      it_behaves_like 'common ai usage rate service', false
    end

    context 'for project' do
      let_it_be(:container) { project.project_namespace.reload }

      let(:expected_results) do
        {
          # Legacy fields
          code_contributors_count: 3,
          code_suggestions_contributors_count: 2,
          code_suggestions_accepted_count: 1,
          code_suggestions_shown_count: 2,
          # New fields
          contributors_count: 2,
          shown_count: 2,
          accepted_count: 1,
          languages: %w[rust ruby],
          shown_lines_of_code: 80,
          accepted_lines_of_code: 20
        }
      end

      let(:expected_language_filtered_results) do
        {
          # Legacy fields do not support languages filter
          code_contributors_count: 3,
          code_suggestions_contributors_count: 2,
          code_suggestions_accepted_count: 1,
          code_suggestions_shown_count: 2,
          # Fields filtered by languages
          contributors_count: 1,
          shown_count: 1,
          accepted_count: 0,
          languages: %w[rust],
          shown_lines_of_code: 50,
          accepted_lines_of_code: 0
        }
      end

      # When use_ai_events_namespace_path_filter is enabled we do not need to
      # run this shared behavior with 'true' parameter because contributors filter won't be used
      it_behaves_like 'common ai usage rate service', false
    end
  end
end
