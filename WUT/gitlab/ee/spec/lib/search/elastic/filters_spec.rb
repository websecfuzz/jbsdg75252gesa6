# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters, feature_category: :global_search do
  include_context 'with filters shared context'
  let_it_be_with_reload(:user) { create(:user) }

  describe '.by_source_branch' do
    subject(:by_source_branch) { described_class.by_source_branch(query_hash: query_hash, options: options) }

    context 'when options[:source_branch] and options[:not_source_branch] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:source_branch] and options[:not_source_branch] are both provided' do
      let(:options) { { source_branch: 'branch-1', not_source_branch: 'branch-2' } }

      it 'adds the source branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { source_branch: { _name: 'filters:source_branch', value: 'branch-1' } } },
              { bool: {
                must_not: {
                  term: { source_branch: { _name: 'filters:not_source_branch', value: 'branch-2' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_source_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_source_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:source_branch] is provided' do
      let(:options) { { source_branch: 'foo-bar-branch' } }

      it 'adds the source branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { source_branch: { _name: 'filters:source_branch', value: 'foo-bar-branch' } } }],
              minimum_should_match: 1 } }
        ]

        expect(by_source_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_source_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_source_branch] is provided' do
      let(:options) { { not_source_branch: 'hello-branch' } }

      it 'adds the source branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { source_branch: { _name: 'filters:not_source_branch', value: 'hello-branch' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_source_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_source_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_target_branch' do
    subject(:by_target_branch) { described_class.by_target_branch(query_hash: query_hash, options: options) }

    context 'when options[:target_branch] and options[:not_target_branch] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:target_branch] and options[:not_target_branch] are both provided' do
      let(:options) { { target_branch: 'branch-1', not_target_branch: 'branch-2' } }

      it 'adds the target branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { target_branch: { _name: 'filters:target_branch', value: 'branch-1' } } },
              { bool: {
                must_not: {
                  term: { target_branch: { _name: 'filters:not_target_branch', value: 'branch-2' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_target_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_target_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:target_branch] is provided' do
      let(:options) { { target_branch: 'foo-bar-branch' } }

      it 'adds the target branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { target_branch: { _name: 'filters:target_branch', value: 'foo-bar-branch' } } }],
              minimum_should_match: 1 } }
        ]

        expect(by_target_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_target_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_target_branch] is provided' do
      let(:options) { { not_target_branch: 'hello-branch' } }

      it 'adds the target branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { target_branch: { _name: 'filters:not_target_branch', value: 'hello-branch' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_target_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_target_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_milestone' do
    let_it_be(:milestone) { create(:milestone) }

    subject(:by_milestone) { described_class.by_milestone(query_hash: query_hash, options: options) }

    context 'when :milestone_title, :not_milestone_title, :none_milestones and :any_milestones options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:milestone_title] is provided' do
      let(:options) { { milestone_title: [milestone.title] } }

      it 'adds the milestone_title filter to query_hash' do
        expected_filter = [{ bool: { must: { terms: { _name: 'filters:milestone_title',
                                                      milestone_title: [milestone.title] } } } }]

        expect(by_milestone.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_milestone.dig(:query, :bool, :must)).to be_empty
        expect(by_milestone.dig(:query, :bool, :must_not)).to be_empty
        expect(by_milestone.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_milestone_title] is provided' do
      let(:options) { { not_milestone_title: [milestone.title] } }

      it 'adds the not_milestone_title filter to query_hash' do
        expected_filter = [{ bool: { must_not: { terms: { _name: 'filters:not_milestone_title',
                                                          milestone_title: [milestone.title] } } } }]

        expect(by_milestone.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_milestone.dig(:query, :bool, :must)).to be_empty
        expect(by_milestone.dig(:query, :bool, :must_not)).to be_empty
        expect(by_milestone.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:any_milestones] is provided' do
      let(:options) { { any_milestones: true } }

      it 'adds the any_milestones filter to query_hash' do
        expected_filter = [{ bool: { _name: 'filters:any_milestones',
                                     must: { exists: { field: 'milestone_title' } } } }]

        expect(by_milestone.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_milestone.dig(:query, :bool, :must)).to be_empty
        expect(by_milestone.dig(:query, :bool, :must_not)).to be_empty
        expect(by_milestone.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:none_milestones] is provided' do
      let(:options) { { none_milestones: true } }

      it 'adds the none_milestones filter to query_hash' do
        expected_filter = [{ bool: { _name: 'filters:none_milestones',
                                     must_not: { exists: { field: 'milestone_title' } } } }]

        expect(by_milestone.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_milestone.dig(:query, :bool, :must)).to be_empty
        expect(by_milestone.dig(:query, :bool, :must_not)).to be_empty
        expect(by_milestone.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:milestone_title] and options[:not_milestone_title] are both provided' do
      let_it_be(:another_milestone) { create(:milestone) }

      let(:options) { { milestone_title: [milestone.title], not_milestone_title: [another_milestone.title] } }

      it 'adds both milestone filters to query_hash' do
        expected_filter = [{
          bool: {
            must: {
              terms: {
                _name: "filters:milestone_title",
                milestone_title: [milestone.title]
              }
            }
          }
        }, {
          bool: {
            must_not: {
              terms: {
                _name: "filters:not_milestone_title",
                milestone_title: [another_milestone.title]
              }
            }
          }
        }]

        expect(by_milestone.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_milestone.dig(:query, :bool, :must)).to be_empty
        expect(by_milestone.dig(:query, :bool, :must_not)).to be_empty
        expect(by_milestone.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_author' do
    let_it_be(:included_user) { user }
    let_it_be(:excluded_user) { create(:user) }

    subject(:by_author) { described_class.by_author(query_hash: query_hash, options: options) }

    context 'when options[:author_username] and options[:not_author_username] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:author_username] and options[:not_author_username] are both provided' do
      let(:options) { { author_username: included_user.username, not_author_username: excluded_user.username } }

      it 'adds the author filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { author_id: { _name: 'filters:author', value: included_user.id } } },
              { bool: {
                must_not: {
                  term: { author_id: { _name: 'filters:not_author', value: excluded_user.id } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_author.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_author.dig(:query, :bool, :must)).to be_empty
        expect(by_author.dig(:query, :bool, :must_not)).to be_empty
        expect(by_author.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:author_username] is provided' do
      let(:options) { { author_username: included_user.username } }

      it 'adds the author filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { author_id: { _name: 'filters:author', value: included_user.id } } }],
              minimum_should_match: 1 } }
        ]

        expect(by_author.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_author.dig(:query, :bool, :must)).to be_empty
        expect(by_author.dig(:query, :bool, :must_not)).to be_empty
        expect(by_author.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_author_username] is provided' do
      let(:options) { { not_author_username: excluded_user.username } }

      it 'adds the author filter to query_hash' do
        expected_filter = [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { author_id: { _name: 'filters:not_author', value: excluded_user.id } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_author.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_author.dig(:query, :bool, :must)).to be_empty
        expect(by_author.dig(:query, :bool, :must_not)).to be_empty
        expect(by_author.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_not_hidden' do
    subject(:by_not_hidden) { described_class.by_not_hidden(query_hash: query_hash, options: options) }

    context 'when options[:current_user] is empty' do
      let(:options) { {} }

      it 'adds the hidden filter to query_hash' do
        expected_filter = [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]

        expect(by_not_hidden.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_not_hidden.dig(:query, :bool, :must)).to be_empty
        expect(by_not_hidden.dig(:query, :bool, :must_not)).to be_empty
        expect(by_not_hidden.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:current_user] is present' do
      let(:options) { { current_user: user } }

      context 'when user cannot read all resources' do
        it 'adds the hidden filter to query_hash' do
          expected_filter = [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]

          expect(by_not_hidden.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_not_hidden.dig(:query, :bool, :must)).to be_empty
          expect(by_not_hidden.dig(:query, :bool, :must_not)).to be_empty
          expect(by_not_hidden.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_state' do
    subject(:by_state) { described_class.by_state(query_hash: query_hash, options: options) }

    context 'when options[:state] is empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] is all' do
      let(:options) { { state: 'all' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains an invalid search state' do
      let(:options) { { state: 'invalid' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains a valid search state' do
      let(:options) { { state: 'opened' } }

      it 'adds the state filter to query_hash' do
        expected_filter = [{ match: { state: { _name: 'filters:state', query: 'opened' } } }]

        expect(by_state.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_state.dig(:query, :bool, :must)).to be_empty
        expect(by_state.dig(:query, :bool, :must_not)).to be_empty
        expect(by_state.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_archived' do
    subject(:by_archived) { described_class.by_archived(query_hash: query_hash, options: options) }

    context 'when search_level not provided in options' do
      let(:options) { {} }

      it 'raises an exception' do
        expect { by_archived }.to raise_exception(ArgumentError)
      end
    end

    context 'when options[:include_archived] is empty or false' do
      let(:options) { { include_archived: false, search_level: 'group' } }

      it 'adds the archived filter to query_hash' do
        expected_filter = [
          { bool: { _name: 'filters:non_archived',
                    should: [
                      { bool: { filter: { term: { archived: { value: false } } } } },
                      { bool: { must_not: { exists: { field: 'archived' } } } }
                    ] } }
        ]

        expect(by_archived.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_archived.dig(:query, :bool, :must)).to be_empty
        expect(by_archived.dig(:query, :bool, :must_not)).to be_empty
        expect(by_archived.dig(:query, :bool, :should)).to be_empty
      end

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: false, search_level: 'project' } }

        it_behaves_like 'does not modify the query_hash'
      end
    end

    context 'when options[:include_archived] is true' do
      let(:options) { { include_archived: true, search_level: 'group' } }

      it_behaves_like 'does not modify the query_hash'

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: true, search_level: 'project' } }

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_knn' do
    let_it_be(:query_hash) do
      { query: { bool: { filter: [
        { term: { archived: { value: false } } }
      ] } } }
    end

    let_it_be(:embedding) { [0.1, 0.2, 0.3] }

    subject(:by_knn) { described_class.by_knn(query_hash: query_hash, options: options) }

    context 'when embedding is present and vectors are supported' do
      let_it_be(:options) { { embeddings: embedding, vectors_supported: :elasticsearch } }

      it 'merges the knn filter into the query_hash' do
        expect(by_knn).to eq(query_hash.deep_merge(knn: { filter: [{ term: { archived: { value: false } } }] }))
      end
    end

    context 'when embedding is not present' do
      let_it_be(:options) { { embeddings: nil } }

      it 'returns the original query_hash' do
        expect(by_knn).to eq(query_hash)
      end
    end

    context 'when vectors are not supported' do
      let_it_be(:options) { { embeddings: embedding, vectors_supported: false } }

      it 'returns the original query_hash' do
        expect(by_knn).to eq(query_hash)
      end
    end
  end

  describe '.by_label_ids' do
    let_it_be(:label_title) { 'My label' }
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: sub_group) }
    # project label must be defined first or the title cannot match
    let_it_be(:project_label) { create(:label, project: project, title: label_title) }
    let_it_be(:project_2) { create(:project, group: group) }
    let_it_be(:project_label_2) { create(:label, project: project_2, title: label_title) }
    let_it_be(:group_label) { create(:group_label, group: group, title: label_title) }
    let_it_be(:another_label) { create(:label, project: project, title: 'Another label') }

    subject(:by_label_ids) { described_class.by_label_ids(query_hash: query_hash, options: options) }

    context 'when options[:label_name] is not provided' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:label_name] is provided' do
      let(:label_name) { [label_title] }
      let(:aggregation) { false }
      let(:count_only) { false }
      let(:group_ids) { nil }
      let(:project_ids) { nil }
      let(:options) do
        {
          label_name: label_name, search_level: search_level, count_only: count_only, aggregation: aggregation,
          group_ids: group_ids, project_ids: project_ids
        }
      end

      context 'when search_level invalid' do
        let(:search_level) { :not_supported }

        it 'raises an exception' do
          expect { by_label_ids }.to raise_exception(ArgumentError)
        end
      end

      context 'when search_level is not provided' do
        let(:options) { { label_name: label_name } }

        it 'raises an exception' do
          expect { by_label_ids }.to raise_exception(ArgumentError)
        end
      end

      context 'for global search' do
        let(:search_level) { :global }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:group_ids] is provided' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash with no group filtering' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end

          context 'when options[:project_ids] is provided' do
            let(:project_ids) { [project.id] }

            it 'adds the label_ids filter to query_hash' do
              expected_filter = [
                bool: {
                  must: [{
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  }]
                }
              ]

              expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
            end
          end
        end

        context 'when options[:project_ids] is provided' do
          using RSpec::Parameterized::TableSyntax

          let(:project_ids) { projects == :any ? projects : [projects.id] }

          where(:projects) do
            [:any, ref(:project), ref(:project_2)]
          end

          with_them do
            it 'adds the label_ids filter to query_hash with no project filtering' do
              expected_filter = [
                bool: {
                  must: [{
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  }]
                }
              ]

              expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
            end
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        it 'adds the label_ids filter to query_hash' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:search_level) { :group }
        let(:group_ids) { [sub_group.id] }
        let(:project_ids) { nil }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when top level group is searched' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when subgroup is searched' do
          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'for project search' do
        let(:search_level) { :project }
        let(:group_ids) { nil }
        let(:project_ids) { [project.id] }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:group_ids] is provided' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash with no group filtering' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        it 'adds the label_ids filter to query_hash' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when options[:labels] and options[:label_name] are provided' do
      let(:options) { { labels: [project_label.id], label_name: [label_title], search_level: :global } }

      it 'uses label_name option and adds the label_ids filter to query_hash' do
        expected_filter = [
          bool: {
            must: [{
              terms: {
                _name: 'filters:label_ids',
                label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
              }
            }]
          }
        ]

        expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
      end

      context 'when options[:count_only] is true' do
        let(:options) { { label_name: [label_title], count_only: true } }

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when options[:aggregation] is true' do
        let(:options) { { label_name: [label_title], aggregation: true } }

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_search_level_and_group_membership' do
    let_it_be_with_reload(:group) { create(:group, :private) }
    let(:base_options) { { current_user: user, search_level: 'global' } }
    let(:options) { base_options }

    subject(:by_search_level_and_group_membership) do
      described_class.by_search_level_and_group_membership(query_hash: query_hash, options: options)
    end

    context 'when no search_level is provided' do
      let(:base_options) { { current_user: user } }

      it 'raises an error' do
        expect { by_search_level_and_group_membership }.to raise_error(ArgumentError)
      end
    end

    context 'when invalid search_level is provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :foobar,
          features: :repository
        }
      end

      it 'raises an error' do
        expect { by_search_level_and_group_membership }.to raise_error(ArgumentError)
      end
    end

    context 'when user.can_read_all_resources? is true' do
      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when user has GUEST permission for the group' do
      before_all do
        group.add_guest(user)
      end

      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }
        let_it_be(:another_group) { create(:group, :private, guests: user) }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
              ],
              should: [
                { prefix:
                  { traversal_ids:
                    { _name: 'filters:permissions:global:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry } } },
                { prefix:
                  { traversal_ids:
                    { _name: 'filters:permissions:global:ancestry_filter:descendants',
                      value: another_group.elastic_namespace_ancestry } } }
              ],
              minimum_should_match: 1
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
              ],
              should: [
                { prefix:
                  { traversal_ids:
                    { _name: 'filters:permissions:group:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry } } }
              ],
              minimum_should_match: 1
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when user is nil' do
      let(:base_options) { { current_user: nil, search_level: 'global' } }

      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }

        it 'shows only the public filter' do
          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:global:namespace_visibility_level:public',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows only the public filter' do
          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:group:namespace_visibility_level:public',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when user has no role in group or project' do
      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }

        it 'shows only the public and internal filters' do
          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows only the public and filters' do
          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when user has GUEST permission for a project in the group hierarchy' do
      let_it_be(:sub_group) { create(:group, :private, parent: group) }
      let_it_be(:project) { create(:project, :private, group: sub_group, guests: user) }

      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } },
                { terms:
                  { _name: 'filters:permissions:global:project:membership',
                    namespace_id: contain_exactly(group.id, sub_group.id) } }
              ]
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end

        context 'and user also has direct permission in a top level group' do
          before_all do
            group.add_guest(user)
          end

          it 'shows private filter for top level group and project namespace ancestors' do
            public_and_internal_filter =
              { bool:
                { filter: [
                  { terms:
                    { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                      namespace_visibility_level:
                        [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                ] } }

            private_filter_top_level_group =
              { bool: {
                minimum_should_match: 1,
                must: [
                  { terms:
                    { _name: 'filters:permissions:global:namespace_visibility_level:private',
                      namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
                ],
                should: [
                  { prefix:
                    { traversal_ids: {
                      _name: 'filters:permissions:global:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry
                    } } }
                ]
              } }

            expected_filter = [
              { bool:
                { _name: 'filters:permissions:global',
                  should: contain_exactly(public_and_internal_filter,
                    private_filter_top_level_group),
                  minimum_should_match: 1 } }
            ]

            expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } },
                { terms:
                  { _name: 'filters:permissions:group:project:membership',
                    namespace_id: contain_exactly(group.id, sub_group.id) } }
              ]
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end

        context 'and user also has direct permission in a top level group' do
          before_all do
            group.add_guest(user)
          end

          it 'shows private filter for top level group only' do
            public_and_internal_filter =
              { bool:
                { filter: [
                  { terms:
                    { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                      namespace_visibility_level:
                        [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                ] } }

            private_filter =
              { bool: {
                minimum_should_match: 1,
                must: [
                  { terms:
                    { _name: 'filters:permissions:group:namespace_visibility_level:private',
                      namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
                ],
                should: [
                  { prefix:
                    { traversal_ids: {
                      _name: 'filters:permissions:group:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry
                    } } }
                ]
              } }

            expected_filter = [
              { bool:
                { _name: 'filters:level:group',
                  should: [
                    { prefix:
                      { traversal_ids:
                        { _name: 'filters:level:group:ancestry_filter:descendants',
                          value: group.elastic_namespace_ancestry } } }
                  ],
                  minimum_should_match: 1 } },
              { bool:
                { _name: 'filters:permissions:group',
                  should: [public_and_internal_filter, private_filter],
                  minimum_should_match: 1 } }
            ]

            expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
          end
        end
      end
    end
  end

  describe '.by_project_authorization' do
    let_it_be_with_reload(:public_group) { create(:group, :public) }
    let_it_be_with_reload(:authorized_project) { create(:project, group: public_group, developers: [user]) }
    let_it_be_with_reload(:private_project) { create(:project, :private, group: public_group) }
    let_it_be_with_reload(:public_project) { create(:project, :public, group: public_group) }
    let(:options) { base_options }
    let(:public_and_internal_projects) { false }
    let(:project_ids) { [] }
    let(:group_ids) { [] }
    let(:features) { 'issues' }
    let(:no_join_project) { false }
    let(:authorization_use_traversal_ids) { true }
    let(:base_options) do
      {
        current_user: user,
        project_ids: project_ids,
        group_ids: group_ids,
        features: features,
        public_and_internal_projects: public_and_internal_projects,
        no_join_project: no_join_project,
        authorization_use_traversal_ids: authorization_use_traversal_ids,
        project_id_field: :project_id,
        project_visibility_level_field: :visibility_level
      }
    end

    subject(:by_project_authorization) do
      described_class.by_project_authorization(query_hash: query_hash, options: options)
    end

    # anonymous users
    context 'when current_user is nil and project_ids is passed empty array' do
      let(:project_ids) { [] }
      let(:user) { nil }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent: { _name: 'filters:project:parent', parent_type: 'project',
                            query: {
                              bool: {
                                should: [
                                  bool: { filter: [
                                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                                    { terms: { _name: 'filters:project:issues:enabled_or_private',
                                               'issues_access_level' => [::ProjectFeature::ENABLED,
                                                 ::ProjectFeature::PRIVATE] } }
                                  ] }
                                ]
                              }
                            } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                ]
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }
        let(:options) { base_options.merge(features: 'issues') }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED } } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                          ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                        ]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ]
              } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', foo: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                            ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                          ]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                        value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when feature access level is set to disabled for the project_ids is passed in array' do
      let(:project_ids) { [public_project.id] }

      before do
        public_project.project_feature.update!(issues_access_level: ::ProjectFeature::DISABLED)
      end

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                ]
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when features is nil' do
        let(:features) { nil }

        context 'when project_ids is :any' do
          let(:project_ids) { :any }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { term: { visibility_level: { _name: 'filters:project:any', value: Project::PRIVATE } } }
                  ] } } } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when project_ids is empty' do
          let(:project_ids) { [] }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } }
                  ] } } } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED } } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED } } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          context 'when project_visibility_level field is set' do
            let(:options) { base_options.merge(project_visibility_level_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                            ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                          ]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { foo: { _name: 'filters:project:visibility:10',
                                           value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { foo: { _name: 'filters:project:visibility:20',
                                           value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                          ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                        ]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ]
              } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', foo: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                            ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                          ]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                        value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                        value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when project_ids is passed :any' do
      let(:project_ids) { :any }

      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [{ bool: { filter: [
                  { term: { visibility_level: { _name: 'filters:project:any',
                                                value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                  { terms: { _name: 'filters:project:issues:enabled_or_private',
                             'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                ] } }] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { _name: 'filters:project',
                        should: [{ bool: { filter: [
                          { term: { visibility_level: { _name: 'filters:project:any',
                                                        value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                          { terms: {
                            _name: 'filters:project:issues:enabled_or_private',
                            'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                          } }
                        ] } }] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: { _name: 'filters:project',
                          should: [{ bool: { filter: [
                            { term: { visibility_level: { _name: 'filters:project:any',
                                                          value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                            { terms: {
                              _name: 'filters:project:issues:enabled_or_private',
                              'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                            } }
                          ] } }] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { term: { visibility_level: { _name: 'filters:project:any',
                                                  value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { terms: {
                          _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { terms: {
                          _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                        } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { _name: 'filters:project',
                        should: [
                          { bool:
                            { filter: [
                              { term: { visibility_level: { _name: 'filters:project:any',
                                                            value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                              { terms: { _name: 'filters:project:issues:enabled_or_private',
                                         'issues_access_level' => [::ProjectFeature::ENABLED,
                                           ::ProjectFeature::PRIVATE] } }
                            ] } },
                          { bool:
                            { _name: 'filters:project:visibility:10:issues:access_level',
                              filter: [
                                { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                              value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                                { terms: {
                                  _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                                  'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                } }
                              ] } },
                          { bool:
                            { _name: 'filters:project:visibility:20:issues:access_level',
                              filter: [
                                { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                              value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                                { terms: {
                                  _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                                  'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                } }
                              ] } }
                        ] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: { _name: 'filters:project',
                          should: [
                            { bool:
                              { filter: [
                                { term: { visibility_level: { _name: 'filters:project:any',
                                                              value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                                { terms: { _name: 'filters:project:issues:enabled_or_private',
                                           'issues_access_level' => [::ProjectFeature::ENABLED,
                                             ::ProjectFeature::PRIVATE] } }
                              ] } },
                            { bool:
                              { _name: 'filters:project:visibility:10:issues:access_level',
                                filter: [
                                  { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                                value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                                  { terms: {
                                    _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                                    'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                  } }
                                ] } },
                            { bool:
                              { _name: 'filters:project:visibility:20:issues:access_level',
                                filter: [
                                  { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                                value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                                  { terms: {
                                    _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                                    'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                  } }
                                ] } }
                          ] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when project_ids is passed an array' do
      let(:project_ids) { [authorized_project.id, private_project.id, public_project.id] }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            has_parent: {
              _name: 'filters:project:parent',
              parent_type: 'project',
              query: {
                bool: {
                  should: [
                    { bool: {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id',
                                   id: contain_exactly(authorized_project.id, public_project.id) } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                  ]
                }
              }
            }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [

              bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id',
                                   project_id: contain_exactly(authorized_project.id, public_project.id) } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                ]
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:custom_field) { :foo }
            let(:options) { base_options.merge(project_id_field: custom_field) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool: {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id',
                                   "#{custom_field}": contain_exactly(authorized_project.id, public_project.id) } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                  ]
                } }
              ]
              expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool:
                    { filter: [
                      { terms: {
                        _name: 'filters:project:membership:id',
                        id: contain_exactly(authorized_project.id, public_project.id)
                      } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private',
                        'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [{ bool: {
              _name: 'filters:project',
              should: [
                { bool:
                  { filter: [
                    { terms: {
                      _name: 'filters:project:membership:id',
                      project_id: contain_exactly(authorized_project.id, public_project.id)
                    } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                { bool:
                  { _name: 'filters:project:visibility:10:issues:access_level',
                    filter: [
                      { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                    value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                      { term: {
                        'issues_access_level' =>
                          { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED }
                      } }
                    ] } },
                { bool:
                  { _name: 'filters:project:visibility:20:issues:access_level',
                    filter: [
                      { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                    value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                      { term: {
                        'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED }
                      } }
                    ] } }
              ]
            } }]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'and project_id_field is provided in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [{ bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: {
                        _name: 'filters:project:membership:id',
                        foo: contain_exactly(authorized_project.id, public_project.id)
                      } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private',
                        'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ]
              } }]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when group_ids is passed an array' do
      let(:group_ids) { [public_group.id] }
      let(:project_ids) { [authorized_project.id, private_project.id, public_project.id] }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { bool: {
              minimum_should_match: 1,
              should: [{
                prefix: {
                  traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants',
                    value: "#{public_group.id}-"
                  }
                }
              }]
            } }
          ]
          expected_must_not = [
            { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when traversal_ids_prefix is set in options' do
          let(:options) { base_options.merge(traversal_ids_prefix: :foo) }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                minimum_should_match: 1,
                should: [{
                  prefix: {
                    foo: {
                      _name: 'filters:namespace:ancestry_filter:descendants',
                      value: "#{public_group.id}-"
                    }
                  }
                }]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when authorization_use_traversal_ids is false in options' do
          let(:authorization_use_traversal_ids) { false }

          it 'returns the expected query' do
            expected_filter = [
              has_parent: {
                _name: 'filters:project:parent',
                parent_type: 'project',
                query: {
                  bool: {
                    should: [
                      { bool: {
                        filter: [
                          { terms: { _name: 'filters:project:membership:id',
                                     id: contain_exactly(authorized_project.id, public_project.id) } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ]
                      } }
                    ]
                  }
                }
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                minimum_should_match: 1,
                should: [
                  { prefix: { traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-"
                  } } }
                ]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when authorization_use_traversal_ids is false in options' do
            let(:authorization_use_traversal_ids) { false }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool: { filter: [
                      { terms:
                        { _name: 'filters:project:membership:id',
                          project_id: contain_exactly(authorized_project.id, public_project.id) } },
                      { terms:
                        { _name: 'filters:project:issues:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                    ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          context 'when traversal_ids_prefix is set in options' do
            let(:options) { base_options.merge(traversal_ids_prefix: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  minimum_should_match: 1,
                  should: [{
                    prefix: {
                      foo: {
                        _name: 'filters:namespace:ancestry_filter:descendants',
                        value: "#{public_group.id}-"
                      }
                    }
                  }]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  minimum_should_match: 1,
                  should: [{
                    prefix: {
                      traversal_ids: {
                        _name: 'filters:namespace:ancestry_filter:descendants',
                        value: "#{public_group.id}-"
                      }
                    }
                  }]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', foo: [private_project.id] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { bool: {
              minimum_should_match: 1,
              should: [{
                prefix: {
                  traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants',
                    value: "#{public_group.id}-"
                  }
                }
              }]
            } }
          ]
          expected_must_not = [
            { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                minimum_should_match: 1,
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
                ]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  minimum_should_match: 1,
                  should: [
                    { prefix:
                      { traversal_ids:
                        { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
                  ]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', foo: [private_project.id] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when user is not authorized for the group_ids' do
        let_it_be(:internal_group) { create(:group, :internal) }
        let_it_be(:private_project) { create(:project, :private, group: internal_group) }
        let_it_be(:internal_project) { create(:project, :internal, group: internal_group) }

        let(:group_ids) { [internal_group.id] }
        let(:project_ids) { [private_project.id, internal_project.id] }

        context 'when public_and_internal_projects is false' do
          let(:public_and_internal_projects) { false }

          it 'returns the expected query' do
            expected_filter = [
              has_parent: {
                _name: 'filters:project:parent',
                parent_type: 'project',
                query: {
                  bool: {
                    should: [
                      { bool: {
                        filter: [
                          { terms: { _name: 'filters:project:membership:id',
                                     id: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ]
                      } }
                    ]
                  }
                }
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when no_join_project is true' do
            let(:no_join_project) { true }

            it 'returns the expected query' do
              expected_filter = [
                { bool:
                  { _name: 'filters:project',
                    should: [
                      bool: {
                        filter: [
                          { terms: { _name: 'filters:project:membership:id', project_id: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ]
                      }
                    ] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end

            context 'when project_id_field is set in options' do
              let(:custom_field) { :foo }
              let(:options) { base_options.merge(project_id_field: custom_field) }

              it 'returns the expected query' do
                expected_filter = [
                  { bool:
                    { _name: 'filters:project',
                      should: [
                        bool: {
                          filter: [
                            { terms: { _name: 'filters:project:membership:id',
                                       "#{custom_field}": [internal_project.id] } },
                            { terms: { _name: 'filters:project:issues:enabled_or_private',
                                       'issues_access_level' => [::ProjectFeature::ENABLED,
                                         ::ProjectFeature::PRIVATE] } }
                          ]
                        }
                      ] } }
                ]

                expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
                expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
              end
            end
          end
        end

        context 'when public_and_internal_projects is true' do
          let(:public_and_internal_projects) { true }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { bool:
                      { filter: [
                        { terms: {
                          _name: 'filters:project:membership:id',
                          id: [internal_project.id]
                        } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                        value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                        value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ] } } } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when no_join_project is true' do
            let(:no_join_project) { true }

            it 'returns the expected query' do
              expected_filter = [
                { bool:
                  { _name: 'filters:project',
                    should: [
                      { bool: { filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [internal_project.id] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ] } },
                      { bool:
                        { _name: 'filters:project:visibility:10:issues:access_level',
                          filter: [
                            { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                          value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                            { term: {
                              'issues_access_level' =>
                                { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                  value: ::ProjectFeature::ENABLED }
                            } }
                          ] } },
                      { bool:
                        { _name: 'filters:project:visibility:20:issues:access_level',
                          filter: [
                            { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                          value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                            { term: {
                              'issues_access_level' =>
                                { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                  value: ::ProjectFeature::ENABLED }
                            } }
                          ] } }
                    ] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end

            context 'when project_id_field is set in options' do
              let(:options) { base_options.merge(project_id_field: :foo) }

              it 'returns the expected query' do
                expected_filter = [
                  { bool:
                    { _name: 'filters:project',
                      should: [
                        { bool: { filter: [
                          { terms: { _name: 'filters:project:membership:id', foo: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ] } },
                        { bool:
                          { _name: 'filters:project:visibility:10:issues:access_level',
                            filter: [
                              { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                            value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                              { term: {
                                'issues_access_level' =>
                                  { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                    value: ::ProjectFeature::ENABLED }
                              } }
                            ] } },
                        { bool:
                          { _name: 'filters:project:visibility:20:issues:access_level',
                            filter: [
                              { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                            value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                              { term: {
                                'issues_access_level' =>
                                  { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                    value: ::ProjectFeature::ENABLED }
                              } }
                            ] } }
                      ] } }
                ]

                expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
                expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
              end
            end
          end
        end
      end
    end
  end

  describe '.by_work_item_type_ids' do
    subject(:by_work_item_type_ids) { described_class.by_work_item_type_ids(query_hash: query_hash, options: options) }

    context 'when options[:work_item_type_ids] and options[:not_work_item_type_ids] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:work_item_type_ids] and options[:not_work_item_type_ids] are both provided' do
      let(:options) { { work_item_type_ids: [1], not_work_item_type_ids: [2] } }

      let(:expected_filter) do
        [
          { bool: {
            must: {
              terms: { work_item_type_id: [1], _name: 'filters:work_item_type_ids' }
            }
          } },
          { bool: { must_not: {
            terms: { work_item_type_id: [2], _name: 'filters:not_work_item_type_ids' }
          } } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:work_item_type_ids] is provided' do
      let(:options) { { work_item_type_ids: [1] } }
      let(:expected_filter) do
        [
          { bool: { must: {
            terms: { work_item_type_id: [1], _name: 'filters:work_item_type_ids' }
          } } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_work_item_type_ids] is provided' do
      let(:options) { { not_work_item_type_ids: [1] } }
      let(:expected_filter) do
        [
          { bool: { must_not: {
            terms: { work_item_type_id: [1], _name: 'filters:not_work_item_type_ids' }
          } } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_type' do
    let(:options) { { doc_type: 'my_type' } }

    subject(:by_type) { described_class.by_type(query_hash: query_hash, options: options) }

    it 'adds the doc type filter to the query_hash' do
      expected_filter = [{ term: { type: { _name: 'filters:doc:is_a:my_type', value: 'my_type' } } }]

      expect(by_type.dig(:query, :bool, :filter)).to eq(expected_filter)
      expect(by_type.dig(:query, :bool, :must)).to be_empty
      expect(by_type.dig(:query, :bool, :must_not)).to be_empty
      expect(by_type.dig(:query, :bool, :should)).to be_empty
    end

    context 'when doc_type not provided in options' do
      let(:options) { {} }

      it 'raises an exception' do
        expect { by_type }.to raise_exception(ArgumentError)
      end
    end
  end

  describe '.by_search_level_and_membership' do
    using RSpec::Parameterized::TableSyntax

    subject(:by_search_level_and_membership) do
      described_class.by_search_level_and_membership(query_hash: query_hash, options: options)
    end

    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_search_level_and_membership' }
    let(:expected_query) do
      json = File.read(Rails.root.join(fixtures_path, fixture_file))
      # the traversal_id for the group the user has access to
      json.gsub!('NAMESPACE_ANCESTRY', namespace_ancestry) if defined?(namespace_ancestry)
      # the project for the project the user has access to
      json.gsub!('PROJECT_ID', project_id.to_s) if defined?(project_id)
      # group search: the traversal_id for the searched group
      json.gsub!('SEARCHED_GROUP', searched_group) if defined?(searched_group)
      # project search: the project_id for the searched project
      json.gsub!('SEARCHED_PROJECT', searched_project.to_s) if defined?(searched_project)
      ::Gitlab::Json.parse(json).deep_symbolize_keys
    end

    let_it_be(:group) { create(:group, :private) }
    let_it_be(:subgroup) { create(:group, :private, parent: group) }
    let_it_be(:project) { create(:project, :private, group: subgroup) }

    context 'when invalid search_level is provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :foobar,
          features: :repository
        }
      end

      it 'raises an error' do
        expect { by_search_level_and_membership }.to raise_error(ArgumentError)
      end
    end

    context 'for global search' do
      let(:search_level) { :global }
      let(:options) do
        {
          current_user: user,
          project_ids: [],
          group_ids: [],
          search_level: search_level,
          features: :repository # repository has different requirements for private projects
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'global_search_user_no_access_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'global_search_user_no_access.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user has access' do
        context 'in group' do
          context 'with reporter role' do
            before_all do
              subgroup.add_reporter(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'global_search_user_access_to_group_as_reporter_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'global_search_user_access_to_group_as_reporter.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end

          context 'with guest role' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'global_search_user_access_to_group_as_guest_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'global_search_user_access_to_group_as_guest.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end
        end

        context 'in project' do
          context 'with reporter role' do
            before_all do
              project.add_reporter(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'global_search_user_access_to_project_as_reporter_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'global_search_user_access_to_project_as_reporter.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end

          context 'with guest role' do
            before_all do
              project.add_guest(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'global_search_user_access_to_project_as_guest_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'global_search_user_access_to_project_as_guest.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end
        end

        context 'in group as guest with read_code custom role' do
          before do
            stub_licensed_features(custom_roles: true)

            read_code_role = create(:member_role, :guest, :read_code, namespace: group)
            create(:group_member, :guest, member_role: read_code_role, user: user, source: group)
          end

          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:fixture_file) { 'global_search_user_access_to_group_with_custom_role_v2.json' }

          it { is_expected.to eq(expected_query) }

          context 'when search_refactor_membership_filter feature flag is false' do
            let(:fixture_file) { 'global_search_user_access_to_group_with_custom_role.json' }

            before do
              stub_feature_flags(search_refactor_membership_filter: false)
            end

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in project when access is shared through another group' do
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:project_id) { project.id.to_s }
          let(:namespace_ancestry) { group_shared.elastic_namespace_ancestry }
          let(:fixture_file) { 'global_search_user_access_to_project_with_shared_group_v2.json' }

          before_all do
            create(:project_group_link, :reporter, project: project, group: group_shared)
          end

          it { is_expected.to eq(expected_query) }

          context 'when search_refactor_membership_filter feature flag is false' do
            let(:fixture_file) { 'global_search_user_access_to_project_with_shared_group.json' }

            before do
              stub_feature_flags(search_refactor_membership_filter: false)
            end

            it { is_expected.to eq(expected_query) }
          end
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:fixture_file) { 'global_search_admin_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'global_search_admin.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:fixture_file) { 'global_search_anonymous_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'global_search_anonymous.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end
    end

    context 'for group search' do
      let(:searched_group) { group.elastic_namespace_ancestry }
      let(:search_level) { :group }
      let(:options) do
        {
          current_user: user,
          project_ids: [],
          group_ids: [group.id],
          search_level: search_level,
          features: :repository,
          project_visibility_level_field: :visibility_level
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'group_search_user_no_access_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'group_search_user_no_access.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user has access' do
        context 'in group' do
          context 'with reporter role' do
            before_all do
              subgroup.add_reporter(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'group_search_user_access_to_group_as_reporter_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'group_search_user_access_to_group_as_reporter.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end

          context 'with guest role' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'group_search_user_access_to_group_as_guest_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'group_search_user_access_to_group_as_guest.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end
        end

        context 'in project' do
          context 'with reporter role' do
            before_all do
              project.add_reporter(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'group_search_user_access_to_project_as_reporter_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'group_search_user_access_to_project_as_reporter.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end

            context 'and searching in the project namespace' do
              let(:fixture_file) { 'group_search_user_access_to_project_as_reporter_v2.json' }
              let(:searched_group) { subgroup.elastic_namespace_ancestry }
              let(:options) do
                {
                  current_user: user,
                  project_ids: [],
                  group_ids: [subgroup.id],
                  search_level: search_level,
                  features: :repository,
                  project_visibility_level_field: :visibility_level
                }
              end

              it { is_expected.to eq(expected_query) }

              context 'when search_refactor_membership_filter feature flag is false' do
                let(:fixture_file) { 'group_search_user_access_to_project_as_reporter.json' }

                before do
                  stub_feature_flags(search_refactor_membership_filter: false)
                end

                it { is_expected.to eq(expected_query) }
              end
            end
          end

          context 'with guest role' do
            before_all do
              project.add_guest(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'group_search_user_access_to_project_as_guest_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'group_search_user_access_to_project_as_guest.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end
        end

        context 'in group as guest with read_code custom role' do
          before do
            stub_licensed_features(custom_roles: true)

            read_code_role = create(:member_role, :guest, :read_code, namespace: group)
            create(:group_member, :guest, member_role: read_code_role, user: user, source: group)
          end

          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:fixture_file) { 'group_search_user_access_to_group_with_custom_role_v2.json' }

          it { is_expected.to eq(expected_query) }

          context 'when search_refactor_membership_filter feature flag is false' do
            let(:fixture_file) { 'group_search_user_access_to_group_with_custom_role.json' }

            before do
              stub_feature_flags(search_refactor_membership_filter: false)
            end

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in project when access is shared through another group' do
          let(:fixture_file) { 'group_search_user_access_to_project_with_shared_group_v2.json' }
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:project_id) { project.id.to_s }

          before_all do
            create(:project_group_link, :reporter, project: project, group: group_shared)
          end

          it { is_expected.to eq(expected_query) }

          context 'when search_refactor_membership_filter feature flag is false' do
            let(:fixture_file) { 'group_search_user_access_to_project_with_shared_group.json' }

            before do
              stub_feature_flags(search_refactor_membership_filter: false)
            end

            it { is_expected.to eq(expected_query) }
          end
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:fixture_file) { 'group_search_admin_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'group_search_admin.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:fixture_file) { 'group_search_anonymous_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'group_search_anonymous.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end
    end

    context 'for project search' do
      let(:searched_project) { project.id.to_s }
      let(:search_level) { :project }
      let(:options) do
        {
          current_user: user,
          project_ids: [project.id],
          group_ids: [group.id],
          search_level: search_level,
          features: :repository,
          project_visibility_level_field: :visibility_level
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'project_search_user_no_access_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'project_search_user_no_access.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user has access' do
        context 'in group' do
          context 'with reporter role' do
            before_all do
              subgroup.add_reporter(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'project_search_user_access_to_group_as_reporter_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'project_search_user_access_to_group_as_reporter.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end

          context 'with guest role' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'project_search_user_access_to_group_as_guest_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'project_search_user_access_to_group_as_guest.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end
        end

        context 'in project' do
          context 'with reporter role' do
            before_all do
              project.add_reporter(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'project_search_user_access_to_project_as_reporter_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'project_search_user_access_to_project_as_reporter.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end

          context 'with guest role' do
            before_all do
              project.add_guest(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'project_search_user_access_to_project_as_guest_v2.json' }

            it { is_expected.to eq(expected_query) }

            context 'when search_refactor_membership_filter feature flag is false' do
              let(:fixture_file) { 'project_search_user_access_to_project_as_guest.json' }

              before do
                stub_feature_flags(search_refactor_membership_filter: false)
              end

              it { is_expected.to eq(expected_query) }
            end
          end
        end

        context 'in group as guest with read_code custom role' do
          before do
            stub_licensed_features(custom_roles: true)

            read_code_role = create(:member_role, :guest, :read_code, namespace: group)
            create(:group_member, :guest, member_role: read_code_role, user: user, source: group)
          end

          let(:namespace_ancestry) { project.namespace.elastic_namespace_ancestry }
          let(:fixture_file) { 'project_search_user_access_to_group_with_custom_role_v2.json' }

          it { is_expected.to eq(expected_query) }

          context 'when search_refactor_membership_filter feature flag is false' do
            let(:fixture_file) { 'project_search_user_access_to_group_with_custom_role.json' }

            before do
              stub_feature_flags(search_refactor_membership_filter: false)
            end

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in project when access is shared through another group' do
          let(:fixture_file) { 'project_search_user_access_to_project_with_shared_group_v2.json' }

          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:project_id) { project.id.to_s }

          before_all do
            create(:project_group_link, :reporter, project: project, group: group_shared)
          end

          it { is_expected.to eq(expected_query) }

          context 'when search_refactor_membership_filter feature flag is false' do
            let(:fixture_file) { 'project_search_user_access_to_project_with_shared_group.json' }

            before do
              stub_feature_flags(search_refactor_membership_filter: false)
            end

            it { is_expected.to eq(expected_query) }
          end
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:fixture_file) { 'project_search_admin_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'project_search_admin.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:fixture_file) { 'project_search_anonymous_v2.json' }

        it { is_expected.to eq(expected_query) }

        context 'when search_refactor_membership_filter feature flag is false' do
          let(:fixture_file) { 'project_search_anonymous.json' }

          before do
            stub_feature_flags(search_refactor_membership_filter: false)
          end

          it { is_expected.to eq(expected_query) }
        end
      end
    end

    context 'when project_visibility_level_field is provided in options' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :global,
          features: :repository,
          project_visibility_level_field: :test_field_name
        }
      end

      let(:fixture_file) { 'global_search_anonymous_custom_project_visibility_level_field_v2.json' }

      it { is_expected.to eq(expected_query) }

      context 'when search_refactor_membership_filter feature flag is false' do
        let(:fixture_file) { 'global_search_anonymous_custom_project_visibility_level_field.json' }

        before do
          stub_feature_flags(search_refactor_membership_filter: false)
        end

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'when multiple features are provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :global,
          features: [:issues, :merge_requests, :repository, :snippets] # mimic notes queries
        }
      end

      let(:fixture_file) { 'global_search_anonymous_multiple_features_v2.json' }

      it { is_expected.to eq(expected_query) }

      context 'when search_refactor_membership_filter feature flag is false' do
        let(:fixture_file) { 'global_search_anonymous_multiple_features.json' }

        before do
          stub_feature_flags(search_refactor_membership_filter: false)
        end

        it { is_expected.to eq(expected_query) }
      end
    end
  end

  describe '.by_noteable_type' do
    let(:query_hash) { { query: { bool: { filter: [] } } } }

    context 'when search_level is global' do
      it 'returns the original query_hash without modifications' do
        options = { search_level: 'global' }

        result = described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(result).to eq(query_hash)
        expect(result).to be(query_hash)
      end
    end

    context 'when noteable_type is not provided' do
      it 'returns the original query_hash without modifications' do
        options = { search_level: 'project' }

        result = described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(result).to eq(query_hash)
        expect(result).to be(query_hash)
      end
    end

    context 'when noteable_type is provided' do
      let(:options) { { search_level: 'project', noteable_type: 'Issue' } }

      it 'sets _source to only include noteable_id' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash[:_source]).to eq(["noteable_id"])
      end

      it 'sets size to DEFAULT_RELATED_SIZE by default' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash[:size]).to eq(described_class::DEFAULT_RELATED_SIZE)
      end

      it 'uses custom related_size when provided' do
        custom_size = 50
        options_with_size = options.merge(related_size: custom_size)

        described_class.by_noteable_type(query_hash: query_hash, options: options_with_size)

        expect(query_hash[:size]).to eq(custom_size)
      end

      it 'creates a term filter with the noteable_type' do
        result = described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(result.dig(:query, :bool, :filter)).to eq([{
          term: {
            noteable_type: {
              _name: 'filters:related:issue',
              value: 'Issue'
            }
          }
        }])
      end
    end
  end

  describe '.by_assignees' do
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }
    let_it_be(:user3) { create(:user) }

    subject(:by_assignees) { described_class.by_assignees(query_hash: query_hash, options: options) }

    context 'when all assignee options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:assignee_ids] is provided' do
      let(:options) { { assignee_ids: [user1.id, user2.id] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:assignee_ids',
            must: [
              { term: { assignee_id: user1.id } },
              { term: { assignee_id: user2.id } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_assignee_ids] is provided' do
      let(:options) { { not_assignee_ids: [user1.id, user2.id] } }
      let(:expected_filter) do
        [{
          bool: {
            must_not: {
              terms: {
                _name: 'filters:not_assignee_ids',
                assignee_id: [user1.id, user2.id]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:or_assignee_ids] is provided' do
      let(:options) { { or_assignee_ids: [user1.id, user2.id] } }
      let(:expected_filter) do
        [{
          bool: {
            must: {
              terms: {
                _name: 'filters:or_assignee_ids',
                assignee_id: [user1.id, user2.id]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_assignees] is provided' do
      let(:options) { { any_assignees: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:any_assignees',
            must: { exists: { field: 'assignee_id' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_assignees] is provided' do
      let(:options) { { none_assignees: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:none_assignees',
            must_not: { exists: { field: 'assignee_id' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:assignee_ids] and options[:not_assignee_ids] are both provided' do
      let(:options) { { assignee_ids: [user1.id], not_assignee_ids: [user2.id, user3.id] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:assignee_ids',
            must: [
              { term: { assignee_id: user1.id } }
            ]
          }
        }, {
          bool: {
            must_not: {
              terms: {
                _name: 'filters:not_assignee_ids',
                assignee_id: [user2.id, user3.id]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_label_names' do
    subject(:by_label_names) { described_class.by_label_names(query_hash: query_hash, options: options) }

    context 'when all label name options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:label_names] is provided' do
      let(:options) { { label_names: ['workflow::complete', 'backend'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow::complete' } },
              { term: { label_names: 'backend' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:label_names] with wildcard is provided' do
      let(:options) { { label_names: ['workflow::*', 'frontend'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { prefix: { label_names: 'workflow::' } },
              { term: { label_names: 'frontend' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_label_names] is provided' do
      let(:options) { { not_label_names: ['workflow::in dev'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { term: { label_names: 'workflow::in dev' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_label_names] with wildcard is provided' do
      let(:options) { { not_label_names: ['group::*'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { prefix: { label_names: 'group::' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:or_label_names] is provided' do
      let(:options) { { or_label_names: ['workflow::complete', 'group::knowledge'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { term: { label_names: 'workflow::complete' } },
              { term: { label_names: 'group::knowledge' } }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:or_label_names] with wildcard is provided' do
      let(:options) { { or_label_names: ['workflow::*', 'backend'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { prefix: { label_names: 'workflow::' } },
              { term: { label_names: 'backend' } }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_label_names] is provided' do
      let(:options) { { any_label_names: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:any_label_names',
            must: { exists: { field: 'label_names' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_label_names] is provided' do
      let(:options) { { none_label_names: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:none_label_names',
            must_not: { exists: { field: 'label_names' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:label_names] and options[:not_label_names] are both provided' do
      let(:options) { { label_names: ['workflow::complete'], not_label_names: ['group::*'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow::complete' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { prefix: { label_names: 'group::' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when complex mixed options are provided' do
      let(:options) do
        {
          label_names: ['workflow::complete'],
          not_label_names: ['group::*'],
          or_label_names: ['workflow::*', 'frontend'],
          any_label_names: false,
          none_label_names: false
        }
      end

      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow::complete' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { prefix: { label_names: 'group::' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { prefix: { label_names: 'workflow::' } },
              { term: { label_names: 'frontend' } }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when mixed ANY with other filters is provided' do
      let(:options) do
        {
          any_label_names: true,
          not_label_names: ['workflow::in dev'],
          or_label_names: %w[frontend backend]
        }
      end

      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { term: { label_names: 'workflow::in dev' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { term: { label_names: 'frontend' } },
              { term: { label_names: 'backend' } }
            ],
            minimum_should_match: 1
          }
        }, {
          bool: {
            _name: 'filters:any_label_names',
            must: { exists: { field: 'label_names' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when label_names with incorrect wildcard patterns are provided' do
      let(:options) { { label_names: ['workflow*', 'backend::', '*workflow', '::workflow'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow*' } },
              { term: { label_names: 'backend::' } },
              { term: { label_names: '*workflow' } },
              { term: { label_names: '::workflow' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end
end
