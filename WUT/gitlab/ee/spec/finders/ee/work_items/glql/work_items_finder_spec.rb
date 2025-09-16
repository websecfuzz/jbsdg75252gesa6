# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Glql::WorkItemsFinder, feature_category: :markdown do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:resource_parent) { group }
  let_it_be(:current_user)    { create(:user) }
  let_it_be(:assignee_user)   { create(:user) }
  let_it_be(:other_user)      { create(:user) }
  let_it_be(:milestone)       { create(:milestone, project: project) }

  let(:context)        { instance_double(GraphQL::Query::Context) }
  let(:request_params) { { 'operationName' => 'GLQL' } }
  let(:url_query)      { 'useES=true' }
  let(:url)            { 'http://localhost' }
  let(:referer)        { "#{url}?#{url_query}" }

  let(:dummy_request) do
    instance_double(ActionDispatch::Request,
      params: request_params,
      referer: referer
    )
  end

  let(:params) do
    {
      label_name: ['test-label'],
      state: 'opened',
      confidential: false,
      author_username: current_user.username,
      milestone_title: [milestone.title],
      assignee_usernames: [assignee_user.username],
      not: {}
    }
  end

  before do
    allow(context).to receive(:[]).with(:request).and_return(dummy_request)
    allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(true)
    allow(resource_parent).to receive(:use_elasticsearch?).and_return(true)
  end

  subject(:finder) { described_class.new(current_user, context, resource_parent, params) }

  describe '#use_elasticsearch_finder?' do
    context 'when falling back to legacy finder' do
      context 'when the request is not a GLQL request' do
        let(:request_params) { { 'operationName' => 'Not GLQL' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when url param is not enabled' do
        let(:url_query) { 'useES=false' }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled per group' do
        before do
          allow(resource_parent).to receive(:use_elasticsearch?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when not supported search param is used' do
        let(:params) { { not_suported: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `not` operator is used with supported filter' do
        let(:params) { { not: { author_username: current_user.username } } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when `not` operator is used with not supported filter' do
        let(:params) { { not: { not_suported: 'something' } } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `not` operator is not a hash' do
        let(:params) { { not: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `or` operator is used with supported filter' do
        let(:params) { { or: { assignee_usernames: [assignee_user.username] } } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when `or` operator is used with not supported filter' do
        let(:params) { { or: { not_suported: 'something' } } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `or` operator is not a hash' do
        let(:params) { { or: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end
    end

    context 'when using ES finder' do
      context 'when all the conditions are met' do
        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when url param is missing (since we do not want to force using this param)' do
        let(:url_query) { '' }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end
    end
  end

  describe '#parent_param=' do
    context 'when resource_parent is a Group' do
      it 'sets the group_id and leaves project_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:project_id]).to be_nil
        expect(finder.params[:group_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is a Project' do
      let_it_be(:resource_parent) { project }

      it 'sets the project_id and leaves group_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:group_id]).to be_nil
        expect(finder.params[:project_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is not allowed' do
      let_it_be(:resource_parent) { create(:merge_request) }

      it 'sets the project_id and leaves group_id nil' do
        expect { finder.parent_param }.to raise_error(RuntimeError, 'Unexpected parent: MergeRequest')
      end
    end
  end

  describe '#execute' do
    let_it_be(:work_item1) { create(:work_item, project: project, author: current_user) }
    let_it_be(:work_item2) { create(:work_item, :satisfied_status, project: project) }
    let(:search_params) do
      {
        source: described_class::GLQL_SOURCE,
        confidential: false,
        label_names: ['test-label'],
        or_label_names: nil,
        not_label_names: nil,
        any_label_names: false,
        none_label_names: false,
        per_page: 100,
        search: '*',
        sort: 'created_desc',
        state: 'opened',
        author_username: current_user.username,
        not_author_username: nil,
        milestone_title: [milestone.title],
        not_milestone_title: nil,
        any_milestones: false,
        none_milestones: false,
        assignee_ids: [assignee_user.id],
        not_assignee_ids: nil,
        or_assignee_ids: nil,
        any_assignees: false,
        none_assignees: false
      }
    end

    let(:search_results_double) { instance_double(Gitlab::Elastic::SearchResults, objects: [work_item1, work_item2]) }
    let(:search_service_double) { instance_double(SearchService, search_results: search_results_double) }

    before do
      finder.parent_param = resource_parent

      allow(SearchService)
        .to receive(:new)
        .with(current_user, search_params)
        .and_return(search_service_double)
    end

    shared_examples 'executes ES search with expected params' do
      it 'executes ES search service' do
        expect(finder.execute).to contain_exactly(work_item1, work_item2)
      end
    end

    context 'when resource_parent is a Project' do
      let(:resource_parent) { project }

      before do
        search_params.merge!(project_id: project.id)
      end

      it_behaves_like 'executes ES search with expected params'
    end

    context 'when resource_parent is a Group' do
      before do
        search_params.merge!(group_id: group.id)
      end

      it_behaves_like 'executes ES search with expected params'
    end

    context 'with additional params' do
      before do
        search_params.merge!(group_id: group.id)
      end

      context 'when not_author_username param provided' do
        before do
          params[:not][:author_username] = current_user.username
          search_params.merge!(not_author_username: current_user.username)
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when not_milestone_title param provided' do
        before do
          params[:not][:milestone_title] = [milestone.title]
          search_params.merge!(not_milestone_title: [milestone.title])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when any_milestones param provided' do
        before do
          params[:milestone_wildcard_id] = described_class::FILTER_ANY
          search_params.merge!(any_milestones: true)
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when none_milestones param provided' do
        before do
          params[:milestone_wildcard_id] = described_class::FILTER_NONE
          search_params.merge!(none_milestones: true)
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when multiple assignee usernames provided' do
        before do
          params[:assignee_usernames] = [assignee_user.username, other_user.username]
          search_params.merge!(assignee_ids: [assignee_user.id, other_user.id])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when not_assignee_usernames param provided' do
        before do
          params[:not][:assignee_usernames] = [assignee_user.username]
          search_params.merge!(not_assignee_ids: [assignee_user.id])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when or assignee param provided' do
        before do
          params[:or] = { assignee_usernames: [assignee_user.username, other_user.username] }
          search_params.merge!(or_assignee_ids: [assignee_user.id, other_user.id])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when any_assignees param provided (assignee wildcard)' do
        before do
          params[:assignee_wildcard_id] = described_class::FILTER_ANY
          search_params.merge!(any_assignees: true)
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when none_assignees param provided (assignee wildcard)' do
        before do
          params[:assignee_wildcard_id] = described_class::FILTER_NONE
          search_params.merge!(none_assignees: true)
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when label_names param provided' do
        before do
          params[:label_name] = ['workflow::complete', 'backend']
          search_params.merge!(label_names: ['workflow::complete', 'backend'])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when label_names param with wildcard provided' do
        before do
          params[:label_name] = ['workflow::*', 'frontend']
          search_params.merge!(label_names: ['workflow::*', 'frontend'])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when not_label_names param provided' do
        before do
          params[:not][:label_name] = ['workflow::in dev']
          search_params.merge!(not_label_names: ['workflow::in dev'])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when not_label_names param with wildcard provided' do
        before do
          params[:not][:label_name] = ['group::*']
          search_params.merge!(not_label_names: ['group::*'])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when or_label_names param provided' do
        before do
          params[:or] = { label_names: ['workflow::complete', 'group::knowledge'] }
          search_params.merge!(or_label_names: ['workflow::complete', 'group::knowledge'])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when or_label_names param with wildcard provided' do
        before do
          params[:or] = { label_names: ['workflow::*', 'backend'] }
          search_params.merge!(or_label_names: ['workflow::*', 'backend'])
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when any_label_names param provided (label wildcard)' do
        before do
          params[:label_name] = [described_class::FILTER_ANY]
          search_params.merge!(
            label_names: nil,
            any_label_names: true
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when none_label_names param provided (label wildcard)' do
        before do
          params[:label_name] = [described_class::FILTER_NONE]
          search_params.merge!(
            label_names: nil,
            none_label_names: true
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when mixed NONE with nested NOT label provided' do
        before do
          params[:label_name] = [described_class::FILTER_NONE]
          params[:not][:label_name] = ['workflow::in dev']
          search_params.merge!(
            label_names: nil,
            none_label_names: true,
            not_label_names: ['workflow::in dev']
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when mixed NONE with OR labels provided' do
        before do
          params[:label_name] = [described_class::FILTER_NONE]
          params[:or] = { label_names: %w[frontend backend] }
          search_params.merge!(
            label_names: nil,
            none_label_names: true,
            or_label_names: %w[frontend backend]
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when mixed ANY with nested NOT label provided' do
        before do
          params[:label_name] = [described_class::FILTER_ANY]
          params[:not][:label_name] = ['workflow::in dev']
          search_params.merge!(
            label_names: nil,
            any_label_names: true,
            not_label_names: ['workflow::in dev']
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when mixed ANY with OR labels provided' do
        before do
          params[:label_name] = [described_class::FILTER_ANY]
          params[:or] = { label_names: %w[frontend backend] }
          search_params.merge!(
            label_names: nil,
            any_label_names: true,
            or_label_names: %w[frontend backend]
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end

      context 'when complex label filtering with wildcards provided' do
        before do
          params[:label_name] = ['workflow::complete']
          params[:not][:label_name] = ['group::*']
          params[:or] = { label_names: ['workflow::*', 'frontend'] }
          search_params.merge!(
            label_names: ['workflow::complete'],
            not_label_names: ['group::*'],
            or_label_names: ['workflow::*', 'frontend']
          )
        end

        it_behaves_like 'executes ES search with expected params'
      end
    end
  end
end
