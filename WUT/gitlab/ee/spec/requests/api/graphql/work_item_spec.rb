# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.work_item(id)', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :private, group: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: project.group)) }
  let_it_be(:project_work_item) do
    create(:work_item, project: project, description: '- List item', weight: 1, iteration: iteration)
  end

  let_it_be(:group_work_item) do
    create(:work_item, :group_level, namespace: group)
  end

  let(:current_user) { guest }
  let(:work_item) { project_work_item }
  let(:work_item_data) { graphql_data['workItem'] }
  let(:work_item_fields) { all_graphql_fields_for('WorkItem') }
  let(:global_id) { work_item.to_gid.to_s }

  let(:query) do
    graphql_query_for('workItem', { 'id' => global_id }, work_item_fields)
  end

  before do
    stub_licensed_features(epics: true)
  end

  context 'when the user can read the work item' do
    context 'when work item is created at the group level' do
      let_it_be(:group_work_item) { create(:work_item, :group_level, namespace: group) }
      let(:global_id) { group_work_item.to_gid.to_s }

      it 'always returns false in the archived field' do
        post_graphql(query, current_user: current_user)

        expect(work_item_data).to include(
          'id' => group_work_item.to_gid.to_s,
          'iid' => group_work_item.iid.to_s,
          'archived' => false
        )
      end

      it 'returns fields based on license availability' do
        post_graphql(query, current_user: current_user)

        expect(work_item_data['userPermissions']['blockedWorkItems']).to be(true)
      end

      context 'without group level work item license' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'returns nil' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data).to be_blank
          expect(graphql_errors.first["message"]).to eq(
            "The resource that you are attempting to access does not exist or you don't have " \
              "permission to perform this action"
          )
        end
      end
    end

    context "for showPlanUpgradePromotion field" do
      context "when the namespace is in a paid plan" do
        before do
          post_graphql(query, current_user: current_user)
        end

        it "returns false" do
          expect(work_item_data).to include('showPlanUpgradePromotion' => false)
        end
      end

      context "when the namespace is in a free plan" do
        before do
          stub_licensed_features(epics: false)
          post_graphql(query, current_user: current_user)
        end

        it "returns true" do
          expect(work_item_data).to include('showPlanUpgradePromotion' => true)
        end
      end
    end

    context 'when querying widgets' do
      describe 'iteration widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetIteration {
                iteration {
                  id
                }
              }
            }
          GRAPHQL
        end

        context 'when iterations feature is licensed' do
          before do
            stub_licensed_features(iterations: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns widget information' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'ITERATION',
                  'iteration' => {
                    'id' => work_item.iteration.to_global_id.to_s
                  }
                )
              )
            )
          end
        end

        context 'when iteration feature is unlicensed' do
          before do
            stub_licensed_features(iterations: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns without iteration' do
            expect(work_item_data['widgets']).not_to include(
              hash_including('type' => 'ITERATION')
            )
          end
        end
      end

      describe 'progress widget' do
        let_it_be(:objective) { create(:work_item, :objective, project: project) }
        let_it_be(:progress) { create(:progress, work_item: objective) }
        let(:global_id) { objective.to_gid.to_s }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetProgress {
                progress
                updatedAt
                currentValue
                startValue
                endValue
              }
            }
          GRAPHQL
        end

        context 'when okrs feature is licensed' do
          before do
            stub_licensed_features(okrs: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns widget information' do
            expect(objective&.work_item_type&.base_type).to match('objective')
            expect(work_item_data).to include(
              'id' => objective.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'PROGRESS',
                  'progress' => objective.progress.progress,
                  'updatedAt' => objective.progress.updated_at&.iso8601,
                  'currentValue' => objective.progress.current_value,
                  'startValue' => objective.progress.start_value,
                  'endValue' => objective.progress.end_value
                )
              )
            )
          end
        end

        context 'when okrs feature is unlicensed' do
          before do
            stub_licensed_features(okrs: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns without progress' do
            expect(objective&.work_item_type&.base_type).to match('objective')
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'PROGRESS'
              )
            )
          end
        end
      end

      describe 'weight widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetWeight {
                widgetDefinition {
                  editable
                  rollUp
                }
                weight
                rolledUpWeight
              }
            }
          GRAPHQL
        end

        context 'when issuable weights is licensed' do
          before do
            stub_licensed_features(issue_weights: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns widget information' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'WEIGHT',
                  'widgetDefinition' => {
                    'editable' => true,
                    'rollUp' => false
                  },
                  'weight' => work_item.weight,
                  'rolledUpWeight' => nil
                )
              )
            )
          end
        end

        context 'when issuable weights is unlicensed' do
          before do
            stub_licensed_features(issue_weights: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns without weight' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'WEIGHT'
              )
            )
          end
        end
      end

      context 'with verification status widget' do
        let_it_be(:work_item) { create(:work_item, :requirement, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetVerificationStatus {
                verificationStatus
              }
            }
          GRAPHQL
        end

        context 'when requirements is licensed' do
          before do
            stub_licensed_features(requirements: true)

            post_graphql(query, current_user: current_user)
          end

          shared_examples 'response with verification status information' do
            it 'returns correct data' do
              expect(work_item_data).to include(
                'id' => work_item.to_gid.to_s,
                'widgets' => include(
                  hash_including(
                    'type' => 'VERIFICATION_STATUS',
                    'verificationStatus' => verification_status
                  )
                )
              )
            end
          end

          context 'when latest test report status is satisfied' do
            let_it_be(:test_report) { create(:test_report, requirement_issue: work_item, state: :passed) }

            it_behaves_like 'response with verification status information' do
              let(:verification_status) { 'satisfied' }
            end
          end

          context 'when latest test report status is failed' do
            let_it_be(:test_report) { create(:test_report, requirement_issue: work_item, state: :failed) }

            it_behaves_like 'response with verification status information' do
              let(:verification_status) { 'failed' }
            end
          end

          context 'with no test report' do
            it_behaves_like 'response with verification status information' do
              let(:verification_status) { 'unverified' }
            end
          end
        end

        context 'when requirements is unlicensed' do
          before do
            stub_licensed_features(requirements: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns no verification status information' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'VERIFICATION_STATUS'
              )
            )
          end
        end
      end

      describe 'status widget' do
        let_it_be(:namespace) { group }
        let_it_be(:custom_status) { create(:work_item_custom_status) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetStatus {
                status {
                  id
                  name
                  iconName
                  color
                  position
                }
              }
            }
          GRAPHQL
        end

        shared_examples 'work item with status widget' do
          context 'when feature is licensed' do
            before do
              stub_licensed_features(work_item_status: true)
            end

            context 'with current status' do
              context 'with system-defined status' do
                let_it_be(:current_status) { create(:work_item_current_status, :system_defined, work_item: work_item) }

                it 'returns system-defined status data' do
                  post_graphql(query, current_user: current_user)

                  expect(work_item_data).to include(
                    'id' => work_item.to_gid.to_s,
                    'widgets' => include(
                      hash_including(
                        'type' => 'STATUS',
                        'status' => {
                          'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
                          'name' => 'To do',
                          'iconName' => 'status-waiting',
                          'color' => "#737278",
                          'position' => 0
                        }
                      )
                    )
                  )
                end
              end

              context 'with custom status' do
                let_it_be(:lifecycle) do
                  create(:work_item_custom_lifecycle, namespace: namespace, default_open_status: custom_status)
                end

                it 'returns custom status data' do
                  create(:work_item_type_custom_lifecycle,
                    lifecycle: lifecycle, work_item_type: work_item.work_item_type, namespace: namespace)

                  current_status = create(:work_item_current_status, :custom, custom_status: custom_status,
                    work_item: work_item)

                  post_graphql(query, current_user: current_user)

                  expect(work_item_data).to include(
                    'id' => work_item.to_gid.to_s,
                    'widgets' => include(
                      hash_including(
                        'type' => 'STATUS',
                        'status' => {
                          'id' => current_status.custom_status.to_gid.to_s,
                          'name' => custom_status.name,
                          'iconName' => 'status-waiting',
                          'color' => "#737278",
                          'position' => 0
                        }
                      )
                    )
                  )
                end
              end
            end

            context 'without current status' do
              it 'returns default status data' do
                post_graphql(query, current_user: current_user)

                expect(work_item_data).to include(
                  'id' => work_item.to_gid.to_s,
                  'widgets' => include(
                    hash_including(
                      'type' => 'STATUS',
                      'status' => {
                        'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
                        'name' => 'To do',
                        'iconName' => 'status-waiting',
                        'color' => "#737278",
                        'position' => 0
                      }
                    )
                  )
                )
              end
            end

            context 'without authorized access' do
              let(:current_user) { nil }

              it 'returns nil' do
                post_graphql(query, current_user: current_user)

                expect(work_item_data).to be_blank
                expect(graphql_errors.first["message"]).to eq(
                  "The resource that you are attempting to access does not exist or you don't have " \
                    "permission to perform this action"
                )
              end
            end
          end

          context 'when feature is unlicensed' do
            before do
              stub_licensed_features(work_item_status: false, epics: true)

              post_graphql(query, current_user: current_user)
            end

            it 'does not return status widget' do
              expect(work_item_data).not_to include(
                'widgets' => include(
                  hash_including(
                    'type' => 'STATUS'
                  )
                )
              )
            end
          end
        end

        context 'with task' do
          let_it_be(:work_item) { create(:work_item, :task, project: project) }

          it_behaves_like 'work item with status widget'
        end

        context 'with issue' do
          let_it_be(:work_item) { create(:work_item, :issue, project: project) }

          it_behaves_like 'work item with status widget'
        end
      end

      describe 'health status widget' do
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }
        let_it_be(:sub_issue) { create(:work_item, :issue, :closed, project: project, health_status: :on_track) }
        let_it_be(:sub_issue_2) { create(:work_item, :issue, project: project, health_status: :at_risk) }
        let_it_be(:sub_task) { create(:work_item, :task, project: project, health_status: :needs_attention) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetHealthStatus {
                healthStatus
                rolledUpHealthStatus {
                  healthStatus
                  count
                }
              }
            }
          GRAPHQL
        end

        before do
          stub_licensed_features(epics: true, issuable_health_status: true)

          work_item.update_attribute(:health_status, :at_risk)

          create(:parent_link, work_item_parent: work_item, work_item: sub_issue)
          create(:parent_link, work_item_parent: work_item, work_item: sub_issue_2)
          create(:parent_link, work_item_parent: sub_issue, work_item: sub_task)

          post_graphql(query, current_user: current_user)
        end

        it 'returns health status widget information' do
          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'HEALTH_STATUS',
                'healthStatus' => 'atRisk',
                'rolledUpHealthStatus' => match_array([
                  { 'healthStatus' => 'onTrack', 'count' => 0 },
                  { 'healthStatus' => 'needsAttention', 'count' => 1 },
                  { 'healthStatus' => 'atRisk', 'count' => 1 }
                ])
              )
            )
          )
        end
      end

      describe 'test reports widget' do
        let_it_be(:work_item) { create(:work_item, :requirement, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetTestReports {
                testReports {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        context 'when requirements is licensed' do
          let_it_be(:test_report1) { create(:test_report, requirement_issue: work_item) }
          let_it_be(:test_report2) { create(:test_report, requirement_issue: work_item) }

          before do
            stub_licensed_features(requirements: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns correct widget data' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'TEST_REPORTS',
                  'testReports' => {
                    'nodes' => array_including(
                      { 'id' => test_report1.to_global_id.to_s },
                      { 'id' => test_report2.to_global_id.to_s }
                    )
                  }
                )
              )
            )
          end
        end

        context 'when requirements is not licensed' do
          before do
            post_graphql(query, current_user: current_user)
          end

          it 'returns empty widget data' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'TEST_REPORTS'
              )
            )
          end
        end
      end

      describe 'labels widget' do
        let(:labels) { create_list(:label, 2, project: project) }
        let(:work_item) { create(:work_item, project: project, labels: labels) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetLabels {
                allowsScopedLabels
                labels {
                  nodes {
                    id
                    title
                  }
                }
              }
            }
          GRAPHQL
        end

        where(:has_scoped_labels_license) do
          [true, false]
        end

        with_them do
          it 'returns widget information' do
            stub_licensed_features(scoped_labels: has_scoped_labels_license)

            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'LABELS',
                  'allowsScopedLabels' => has_scoped_labels_license,
                  'labels' => {
                    'nodes' => match_array(
                      labels.map { |a| { 'id' => a.to_gid.to_s, 'title' => a.title } }
                    )
                  }
                )
              )
            )
          end
        end
      end

      describe 'legacy requirement widget' do
        let_it_be(:work_item) { create(:work_item, :requirement, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetRequirementLegacy {
                type
                legacyIid
              }
            }
          GRAPHQL
        end

        context 'when requirements is licensed' do
          before do
            stub_licensed_features(requirements: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns correct data' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'REQUIREMENT_LEGACY',
                  'legacyIid' => work_item.requirement.iid
                )
              )
            )
          end
        end

        context 'when requirements is unlicensed' do
          before do
            stub_licensed_features(requirements: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns no legacy requirement information' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'REQUIREMENT_LEGACY',
                'legacyIid' => work_item.requirement.iid
              )
            )
          end
        end
      end

      describe 'notes widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetNotes {
                system: discussions(filter: ONLY_ACTIVITY, first: 10) { nodes { id  notes { nodes { id system internal body } } } },
                comments: discussions(filter: ONLY_COMMENTS, first: 10) { nodes { id  notes { nodes { id system internal body } } } },
                all_notes: discussions(filter: ALL_NOTES, first: 10) { nodes { id  notes { nodes { id system internal body } } } }
              }
            }
          GRAPHQL
        end

        it 'fetches notes that require gitaly call to parse note' do
          # this 9 digit long weight triggers a gitaly call when parsing the system note
          create(:resource_weight_event, user: current_user, issue: work_item, weight: 123456789)

          post_graphql(query, current_user: current_user)

          expect_graphql_errors_to_be_empty
        end

        context 'when work item is associated with a group' do
          let_it_be(:group_work_item) { create(:work_item, :group_level, namespace: group) }
          let_it_be(:group_work_item_note) { create(:note, noteable: group_work_item, author: developer, project: nil) }

          let(:global_id) { group_work_item.to_gid.to_s }
          let(:work_item_fields) do
            <<~GRAPHQL
              id
              widgets {
                type
                ... on WorkItemWidgetNotes {
                  discussions(filter: ONLY_COMMENTS, first: 10) {
                    nodes {
                      id
                      notes {
                        nodes {
                          id
                          body
                          maxAccessLevelOfAuthor
                          authorIsContributor
                          awardEmoji {
                            nodes {
                              name
                              user {
                                name
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            GRAPHQL
          end

          before_all do
            create(:award_emoji, awardable: group_work_item_note, name: 'rocket', user: developer)
          end

          it 'returns notes for the group work item' do
            post_graphql(query, current_user: current_user)

            all_widgets = graphql_dig_at(work_item_data, :widgets)
            notes_widget = all_widgets.find { |x| x['type'] == 'NOTES' }
            notes = graphql_dig_at(notes_widget['discussions'], :nodes).flat_map { |d| d['notes']['nodes'] }

            expect(notes).to contain_exactly(
              hash_including('body' => group_work_item_note.note)
            )
          end

          it 'skips check read_note ability on graphql types' do
            expect(Ability).not_to receive(:allowed?).with(
              current_user, :read_emoji, anything
            )
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).twice.with(
              current_user, :read_note, anything
            ).and_call_original

            post_graphql(query, current_user: current_user)
          end
        end

        context 'when fetching description version diffs' do
          shared_examples 'description change diff' do |description_diffs_enabled: true|
            it 'returns previous description change diff' do
              post_graphql(query, current_user: developer)

              # check that system note is added
              note = find_note(work_item, 'changed the description') # system note about changed description
              expect(work_item.reload.description).to eq('updated description')
              expect(note.note).to eq('changed the description')

              # check that diff is returned
              all_widgets = graphql_dig_at(work_item_data, :widgets)
              notes_widget = all_widgets.find { |x| x["type"] == "NOTES" }

              system_notes = graphql_dig_at(notes_widget["system"], :nodes)
              description_changed_note = graphql_dig_at(system_notes.first["notes"], :nodes).first
              description_version = graphql_dig_at(description_changed_note['systemNoteMetadata'], :descriptionVersion)

              id = GitlabSchema.parse_gid(description_version['id'], expected_type: ::DescriptionVersion).model_id
              diff = description_version['diff']
              diff_path = description_version['diffPath']
              delete_path = description_version['deletePath']
              can_delete = description_version['canDelete']
              deleted = description_version['deleted']

              if description_diffs_enabled
                expect(diff).to eq("<span class=\"idiff addition\">updated description</span>")
                expect(diff_path).to eq(expected_diff_path(id))
                expect(delete_path).to eq(expected_delete_path(id))
                expect(can_delete).to be true
              else
                expect(diff).to be_nil
                expect(diff_path).to be_nil
                expect(delete_path).to be_nil
                expect(can_delete).to be_nil
              end

              expect(deleted).to be false
            end

            def url_helper
              ::Gitlab::Routing.url_helpers
            end

            def expected_diff_path(id)
              if work_item.project.blank?
                url_helper.description_diff_group_work_item_path(work_item.resource_parent, work_item.iid, id)
              else
                url_helper.description_diff_project_issue_path(work_item.resource_parent, work_item.iid, id)
              end
            end

            def expected_delete_path(id)
              if work_item.project.blank?
                url_helper.delete_description_version_group_work_item_path(work_item.resource_parent, work_item.iid, id)
              else
                url_helper.delete_description_version_project_issue_path(work_item.resource_parent, work_item.iid, id)
              end
            end

            def find_note(work_item, starting_with)
              work_item.notes.find do |note|
                break note if note && note.note.start_with?(starting_with)
              end
            end
          end

          let_it_be_with_reload(:work_item) { create(:work_item, project: project) }

          let(:work_item_fields) do
            <<~GRAPHQL
              id
              widgets {
                type
                ... on WorkItemWidgetNotes {
                  system: discussions(filter: ONLY_ACTIVITY, first: 10) {
                    nodes {
                      id
                      notes {
                        nodes {
                          id
                          system
                          internal
                          body
                          systemNoteMetadata {
                            id
                            descriptionVersion {
                              id
                              diff(versionId: #{version_gid})
                              diffPath
                              deletePath
                              canDelete
                              deleted
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            GRAPHQL
          end

          let(:version_gid) { "null" }
          let(:opts) { { description: 'updated description' } }

          let(:service) do
            WorkItems::UpdateService.new(
              container: work_item.resource_parent,
              current_user: developer,
              params: opts,
              widget_params: {}
            )
          end

          before do
            service.execute(work_item)
          end

          context 'when work item belongs to a project' do
            it_behaves_like 'description change diff'

            context 'with passed description version id' do
              let(:version_gid) { "\"#{work_item.description_versions.first.to_global_id}\"" }

              it_behaves_like 'description change diff'
            end

            context 'with description_diffs disabled' do
              before do
                stub_licensed_features(description_diffs: false)
              end

              it_behaves_like 'description change diff', description_diffs_enabled: false
            end

            context 'with description_diffs enabled' do
              before do
                stub_licensed_features(description_diffs: true)
              end

              it_behaves_like 'description change diff', description_diffs_enabled: true
            end
          end

          context 'when work item belongs to a group' do
            let(:work_item) { group_work_item }

            it_behaves_like 'description change diff'
          end
        end
      end

      describe 'linked items widget' do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:related_item) { create(:work_item, project: project) }
        let_it_be(:blocked_item) { create(:work_item, project: project) }
        let_it_be(:blocking_item) { create(:work_item, project: project) }
        let_it_be(:link1) do
          create(:work_item_link, source: project_work_item, target: related_item, link_type: 'relates_to')
        end

        let_it_be(:link2) do
          create(:work_item_link, source: project_work_item, target: blocked_item, link_type: 'blocks')
        end

        let_it_be(:link3) do
          create(:work_item_link, source: blocking_item, target: project_work_item, link_type: 'blocks')
        end

        let(:filter_type) { 'RELATED' }
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetLinkedItems {
                blocked
                blockedByCount
                blockingCount
                linkedItems(filter: #{filter_type}) {
                  nodes {
                    linkId
                    linkType
                    linkCreatedAt
                    linkUpdatedAt
                    workItem {
                      id
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        context 'when request is successful' do
          where(:filter_type, :item, :link, :expected) do
            'RELATED'    | ref(:related_item)  | ref(:link1) | 'relates_to'
            'BLOCKS'     | ref(:blocked_item)  | ref(:link2) | 'blocks'
            'BLOCKED_BY' | ref(:blocking_item) | ref(:link3) | 'is_blocked_by'
          end

          with_them do
            it 'returns widget information' do
              post_graphql(query, current_user: current_user)

              expect(work_item_data).to include(
                'widgets' => include(
                  hash_including(
                    'type' => 'LINKED_ITEMS',
                    'blocked' => true,
                    'blockedByCount' => 1,
                    'blockingCount' => 1,
                    'linkedItems' => { 'nodes' => match_array(
                      [
                        hash_including(
                          'linkId' => link.to_gid.to_s, 'linkType' => expected,
                          'linkCreatedAt' => link.created_at.iso8601, 'linkUpdatedAt' => link.updated_at.iso8601,
                          'workItem' => { 'id' => item.to_gid.to_s }
                        )
                      ]
                    ) }
                  )
                )
              )
            end
          end

          it 'avoids N+1 queries', :use_sql_query_cache do
            post_graphql(query, current_user: current_user) # warmup
            control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              post_graphql(query, current_user: current_user)
            end

            create_list(:work_item, 3, project: project) do |item|
              create(:work_item_link, source: item, target: work_item, link_type: 'blocks')
            end

            expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
            expect_graphql_errors_to_be_empty
          end
        end

        context 'when work item belongs to a group' do
          let(:work_item) { group_work_item }

          before do
            create(:work_item_link, source: work_item, target: related_item, link_type: 'relates_to')
            create(:work_item_link, source: work_item, target: blocked_item, link_type: 'blocks')
            create(:work_item_link, source: blocking_item, target: work_item, link_type: 'blocks')
          end

          it 'returns widget information' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'widgets' => include(
                hash_including(
                  'type' => 'LINKED_ITEMS',
                  'blocked' => true,
                  'blockedByCount' => 1,
                  'blockingCount' => 1
                )
              )
            )
          end
        end
      end

      describe 'hierarchy widget' do
        let_it_be(:other_group) { create(:group, :private) }
        let_it_be(:other_project) { create(:project, group: other_group) }

        let_it_be(:ancestor3) { create(:work_item, :epic, namespace: group) }
        let_it_be(:private_ancestor) { create(:work_item, :epic, namespace: other_group, work_item_parent: ancestor3) }
        let_it_be(:ancestor2) { create(:work_item, :epic, namespace: group, work_item_parent: private_ancestor) }
        let_it_be(:ancestor1) { create(:work_item, :epic, namespace: group, work_item_parent: ancestor2) }
        let_it_be(:parent_epic) { create(:work_item, :epic, project: project, work_item_parent: ancestor1) }
        let_it_be(:work_item) { create(:work_item, :epic, project: project, work_item_parent: parent_epic) }
        let_it_be(:child_issue) { create(:work_item, :issue, project: project, work_item_parent: work_item) }
        let_it_be(:child_epic) { create(:work_item, :epic, project: project, work_item_parent: work_item) }
        let_it_be(:private_child) { create(:work_item, :issue, project: other_project, work_item_parent: work_item) }

        let(:current_user) { developer }
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              ... on WorkItemWidgetHierarchy {
                parent {
                  id
                  webUrl
                }
                children {
                  nodes {
                    id
                    webUrl
                  }
                }
                ancestors {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        it 'returns authorized widget information' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'parent' => {
                  'id' => parent_epic.to_gid.to_s,
                  'webUrl' => "#{Gitlab.config.gitlab.url}/#{project.full_path}/-/work_items/#{parent_epic.iid}"
                },
                'children' => { 'nodes' => match_array(
                  [
                    hash_including(
                      'id' => child_issue.to_gid.to_s,
                      'webUrl' => "#{Gitlab.config.gitlab.url}/#{project.full_path}/-/issues/#{child_issue.iid}"
                    ),
                    hash_including(
                      'id' => child_epic.to_gid.to_s,
                      'webUrl' => "#{Gitlab.config.gitlab.url}/#{project.full_path}/-/work_items/#{child_epic.iid}"
                    )
                  ]) },
                'ancestors' => { 'nodes' => match_array(
                  # truncates ancestors up to the last visible one
                  [
                    hash_including('id' => ancestor2.to_gid.to_s),
                    hash_including('id' => ancestor1.to_gid.to_s),
                    hash_including('id' => parent_epic.to_gid.to_s)
                  ]
                ) }
              )
            )
          )
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          # Grant access to the top ancestor
          other_group.add_guest(current_user)
          post_graphql(query, current_user: current_user) # warm-up

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end
          expect_graphql_errors_to_be_empty

          # Use a different group hierarchy to test preloaders properly
          other_group2 = create(:group, :private, guests: current_user)
          other_group3 = create(:group, :private, guests: current_user)
          other_project2 = create(:project, :private, guests: current_user)

          create(:work_item, :epic, namespace: other_group2).tap do |new_ancestor|
            ancestor3.update!(work_item_parent: new_ancestor)
          end

          create(:work_item, :issue, project: other_project2, work_item_parent: work_item)
          create(:work_item, :epic, namespace: other_group3, work_item_parent: work_item)

          expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        end

        context 'when work item belongs to a user namespace project' do
          let_it_be(:user_namespace_project) { create(:project, namespace: developer.namespace) }
          let_it_be(:ancestor) { create(:work_item, :epic, project: user_namespace_project) }
          let_it_be(:work_item) { create(:work_item, project: user_namespace_project, work_item_parent: ancestor) }

          let(:global_id) { work_item.to_gid.to_s }

          it 'returns ancestor information' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'widgets' => include(
                hash_including(
                  'ancestors' => { 'nodes' => match_array(
                    [
                      hash_including('id' => ancestor.to_gid.to_s)
                    ]
                  ) }
                )
              )
            )
          end

          context 'when user does not have access' do
            it 'does not return anything' do
              post_graphql(query, current_user: guest)

              expect(work_item_data).to be_nil
            end
          end
        end

        context 'when not signed in' do
          let(:current_user) { nil }
          let(:work_item_fields) do
            <<~GRAPHQL
              widgets {
                ... on WorkItemWidgetHierarchy {
                  ancestors {
                    nodes {
                      id
                    }
                  }
                }
              }
            GRAPHQL
          end

          context 'when project is private' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it 'does not list any ancestors' do
              post_graphql(query, current_user: current_user)

              expect(work_item_data).to be_nil
            end
          end

          context 'when project is public' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
            end

            context 'when partial ancestors are accessible' do
              it 'truncates ancestors up to the last visible one' do
                post_graphql(query, current_user: current_user)

                expect(work_item_data).to include(
                  'widgets' => include(
                    hash_including(
                      'ancestors' => { 'nodes' => match_array(
                        [
                          hash_including('id' => ancestor2.to_gid.to_s),
                          hash_including('id' => ancestor1.to_gid.to_s),
                          hash_including('id' => parent_epic.to_gid.to_s)
                        ]
                      ) }
                    )
                  )
                )
              end
            end

            context 'when all ancestors are accessible' do
              before do
                other_group.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
              end

              it 'shows all ancestors' do
                post_graphql(query, current_user: current_user)

                expect(work_item_data).to include(
                  'widgets' => include(
                    hash_including(
                      'ancestors' => { 'nodes' => match_array(
                        [
                          hash_including('id' => ancestor3.to_gid.to_s),
                          hash_including('id' => private_ancestor.to_gid.to_s),
                          hash_including('id' => ancestor2.to_gid.to_s),
                          hash_including('id' => ancestor1.to_gid.to_s),
                          hash_including('id' => parent_epic.to_gid.to_s)
                        ]
                      ) }
                    )
                  )
                )
              end
            end
          end
        end
      end

      describe 'color widget' do
        let_it_be(:epic) { create(:work_item, :epic, namespace: group) }
        let_it_be(:color) { create(:color, work_item: epic) }
        let_it_be(:global_id) { epic.to_gid.to_s }

        let(:work_item_fields) do
          <<~GRAPHQL
            id,
            widgets {
              type
              ... on WorkItemWidgetColor {
                color
                textColor
              }
            }
          GRAPHQL
        end

        context 'when work item epics available ' do
          before do
            stub_licensed_features(epics: true, epic_colors: true)
          end

          it 'returns widget information' do
            post_graphql(query, current_user: current_user)

            expect(epic&.work_item_type&.base_type).to match('epic')
            expect(work_item_data).to include(
              'widgets' => include(
                hash_including(
                  'type' => 'COLOR',
                  'color' => epic.color&.color&.to_s,
                  'textColor' => epic.color&.text_color&.to_s
                )
              )
            )
          end

          it 'avoids N+1 queries', :use_sql_query_cache do
            post_graphql(query, current_user: current_user) # warmup
            control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              post_graphql(query, current_user: current_user)
            end

            create_list(:work_item, 3, namespace: group) do |item|
              create(:color, work_item: item)
            end

            expect do
              post_graphql(query, current_user: current_user)
            end.to issue_same_number_of_queries_as(control_count)
            expect_graphql_errors_to_be_empty
          end
        end

        context 'when work item epics is unavailable' do
          it 'returns without color' do
            post_graphql(query, current_user: current_user)

            expect(epic&.work_item_type&.base_type).to match('epic')
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'COLOR'
              )
            )
          end
        end
      end

      describe 'dates rolledup widget' do
        let_it_be(:start_date) { 5.days.ago }
        let_it_be(:due_date) { 5.days.from_now }

        context 'with fixed dates' do
          let_it_be(:epic) { create(:work_item, :epic, namespace: group) }

          let(:global_id) { epic.to_gid.to_s }

          let(:work_item_fields) do
            <<~GRAPHQL
              id
              workItemType {
                id
                name
              }
              widgets {
                type
                ... on WorkItemWidgetStartAndDueDate {
                  isFixed
                  rollUp
                  dueDate
                  dueDateSourcingMilestone { id }
                  dueDateSourcingWorkItem { id }
                  startDate
                  startDateSourcingMilestone { id }
                  startDateSourcingWorkItem { id }
                }
              }
            GRAPHQL
          end

          before do
            create(
              :work_items_dates_source,
              work_item: epic,
              due_date: due_date,
              due_date_sourcing_milestone: nil,
              start_date: start_date,
              start_date_sourcing_milestone: nil)
          end

          it 'returns widget information' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'id' => epic.to_global_id.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'START_AND_DUE_DATE',
                  'rollUp' => true,
                  'isFixed' => false,
                  'dueDate' => due_date.to_date.to_s,
                  'dueDateSourcingMilestone' => nil,
                  'dueDateSourcingWorkItem' => nil,
                  'startDate' => start_date.to_date.to_s,
                  'startDateSourcingMilestone' => nil,
                  'startDateSourcingWorkItem' => nil
                )
              )
            )
          end
        end

        context 'with dates from child' do
          let_it_be(:epic) { create(:work_item, :epic, namespace: group) }
          let_it_be(:child_work_item) { create(:work_item, :issue, namespace: group) }

          let(:global_id) { epic.to_gid.to_s }

          let(:work_item_fields) do
            <<~GRAPHQL
              id
              workItemType {
                id
                name
              }
              widgets {
                type
                ... on WorkItemWidgetStartAndDueDate {
                  rollUp
                  isFixed
                  dueDate
                  dueDateSourcingMilestone { id }
                  dueDateSourcingWorkItem { id }
                  startDate
                  startDateSourcingMilestone { id }
                  startDateSourcingWorkItem { id }
                }
              }
            GRAPHQL
          end

          before do
            create(
              :work_items_dates_source,
              work_item: epic,
              due_date: due_date,
              due_date_sourcing_work_item: child_work_item,
              start_date: start_date,
              start_date_sourcing_work_item: child_work_item)
          end

          it 'returns widget information' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'id' => epic.to_global_id.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'START_AND_DUE_DATE',
                  'rollUp' => true,
                  'isFixed' => false,
                  'dueDate' => due_date.to_date.to_s,
                  'dueDateSourcingMilestone' => nil,
                  'dueDateSourcingWorkItem' => {
                    'id' => child_work_item.to_global_id.to_s
                  },
                  'startDate' => start_date.to_date.to_s,
                  'startDateSourcingMilestone' => nil,
                  'startDateSourcingWorkItem' => {
                    'id' => child_work_item.to_global_id.to_s
                  }
                )
              )
            )
          end
        end

        context 'with dates from milestone' do
          let_it_be(:milestone) { create(:milestone, project: project, start_date: start_date, due_date: due_date) }
          let_it_be(:epic) { create(:work_item, :epic, namespace: group) }

          let(:global_id) { epic.to_gid.to_s }

          let(:work_item_fields) do
            <<~GRAPHQL
              id
              workItemType {
                id
                name
              }
              widgets {
                type
                ... on WorkItemWidgetStartAndDueDate {
                  rollUp
                  isFixed
                  dueDate
                  dueDateSourcingMilestone { id }
                  dueDateSourcingWorkItem { id }
                  startDate
                  startDateSourcingMilestone { id }
                  startDateSourcingWorkItem { id }
                }
              }
            GRAPHQL
          end

          before do
            create(
              :work_items_dates_source,
              work_item: epic,
              due_date: due_date,
              due_date_sourcing_milestone: milestone,
              start_date: start_date,
              start_date_sourcing_milestone: milestone)
          end

          it 'returns widget information' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'id' => epic.to_global_id.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'START_AND_DUE_DATE',
                  'rollUp' => true,
                  'isFixed' => false,
                  'dueDate' => due_date.to_date.to_s,
                  'dueDateSourcingMilestone' => {
                    'id' => milestone.to_global_id.to_s
                  },
                  'dueDateSourcingWorkItem' => nil,
                  'startDate' => start_date.to_date.to_s,
                  'startDateSourcingMilestone' => {
                    'id' => milestone.to_global_id.to_s
                  },
                  'startDateSourcingWorkItem' => nil
                )
              )
            )
          end
        end
      end

      describe 'development widget' do
        context 'when fetching related feature flags' do
          let_it_be(:feature_flags) { create_list(:operations_feature_flag, 4, project: project) }
          let(:work_item_fields) do
            <<~GRAPHQL
              id
              widgets {
                type
                ... on WorkItemWidgetDevelopment {
                  featureFlags {
                    nodes {
                      id
                      name
                    }
                  }
                }
              }
            GRAPHQL
          end

          before_all do
            feature_flags.each { |ff| create(:feature_flag_issue, issue_id: project_work_item.id, feature_flag: ff) }
          end

          before do
            post_graphql(query, current_user: current_user)
          end

          context 'when user is developer' do
            let(:current_user) { developer }

            it 'returns related feature flags in the response' do
              expect(work_item_data['widgets']).to include(
                'type' => 'DEVELOPMENT', 'featureFlags' => {
                  'nodes' => match_array(
                    feature_flags.map { |ff| hash_including('id' => ff.to_gid.to_s, 'name' => ff.name) }
                  )
                }
              )
            end

            it 'avoids N + 1 queries', :use_sql_query_cache do
              # warm-up already don in the before block
              control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                post_graphql(query, current_user: current_user)
              end

              2.times do
                create(
                  :feature_flag_issue,
                  issue_id: work_item.id,
                  feature_flag: create(:operations_feature_flag, project: project)
                )
              end

              expect do
                post_graphql(query, current_user: current_user)
              end.to issue_same_number_of_queries_as(control)
            end
          end

          context 'when user is guest' do
            let(:current_user) { guest }

            it 'returns an empty list of feature flags' do
              expect(work_item_data['widgets']).to include(
                'type' => 'DEVELOPMENT', 'featureFlags' => {
                  'nodes' => []
                }
              )
            end
          end
        end
      end

      shared_examples 'avoids N+1 queries for processing participants' do
        specify do
          users = create_list(:user, 6)

          # Add 3 participant to the legacy epic
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: work_item, user: users[0])
          note = create(:note, noteable: work_item.synced_epic, author: users[1], project: project)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: note, user: users[2])

          post_graphql(query, current_user: current_user) # warm-up

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end

          # Add 3 more participants to the legacy epic
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: work_item.synced_epic, user: users[3])
          note = create(:note, noteable: work_item.synced_epic, author: users[4], project: project)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: note, user: users[5])

          expect do
            post_graphql(query, current_user: current_user)
          end.not_to exceed_all_query_limit(control)
        end
      end

      describe 'notifications widget' do
        let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetNotifications {
                subscribed
              }
            }
          GRAPHQL
        end

        before do
          stub_licensed_features(epics: true)
        end

        it 'returns widget information' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'NOTIFICATIONS',
                'subscribed' => work_item.subscribed?(current_user, project)
              )
            )
          )
        end

        it_behaves_like 'avoids N+1 queries for processing participants'
      end

      describe 'participants widget' do
        let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetParticipants {
                participants {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        before do
          stub_licensed_features(epics: true)
        end

        it 'returns participants' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'PARTICIPANTS',
                'participants' => { 'nodes' => [{ "id" => "gid://gitlab/User/#{work_item.author.id}" }] }
              )
            )
          )
        end

        it_behaves_like 'avoids N+1 queries for processing participants'
      end

      describe 'custom fields widget' do
        include_context 'with group configured with custom fields'

        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:work_item) { create(:work_item, work_item_type: issue_type, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetCustomFields {
                customFieldValues {
                  customField {
                    id
                  }
                  ... on WorkItemTextFieldValue {
                    value
                  }
                  ... on WorkItemNumberFieldValue {
                    value
                  }
                  ... on WorkItemSelectFieldValue {
                    selectedOptions {
                      id
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        before_all do
          group.add_guest(guest)

          create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'text value')
          create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 10)

          create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
            custom_field_select_option: select_option_2)

          create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
            custom_field_select_option: multi_select_option_3)
          create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
            custom_field_select_option: multi_select_option_1)
        end

        before do
          stub_licensed_features(custom_fields: true)
        end

        it 'returns widget information' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'CUSTOM_FIELDS',
                'customFieldValues' => [
                  {
                    'customField' => { 'id' => select_field.to_gid.to_s },
                    'selectedOptions' => [
                      { 'id' => select_option_2.to_gid.to_s }
                    ]
                  },
                  {
                    'customField' => { 'id' => number_field.to_gid.to_s },
                    'value' => 10
                  },
                  {
                    'customField' => { 'id' => text_field.to_gid.to_s },
                    'value' => 'text value'
                  },
                  {
                    'customField' => { 'id' => multi_select_field.to_gid.to_s },
                    'selectedOptions' => [
                      { 'id' => multi_select_option_1.to_gid.to_s },
                      { 'id' => multi_select_option_3.to_gid.to_s }
                    ]
                  }
                ]
              )
            )
          )
        end

        context 'when only some custom field values are requested' do
          let(:work_item_fields) do
            <<~GRAPHQL
              id
              widgets {
                type
                ... on WorkItemWidgetCustomFields {
                  customFieldValues(customFieldIds: ["#{text_field.to_gid}", "#{number_field.to_gid}"]) {
                    customField {
                      id
                    }
                    ... on WorkItemTextFieldValue {
                      value
                    }
                    ... on WorkItemNumberFieldValue {
                      value
                    }
                    ... on WorkItemSelectFieldValue {
                      selectedOptions {
                        id
                      }
                    }
                  }
                }
              }
            GRAPHQL
          end

          it 'only returns requested custom field values' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'CUSTOM_FIELDS',
                  'customFieldValues' => [
                    {
                      'customField' => { 'id' => number_field.to_gid.to_s },
                      'value' => 10
                    },
                    {
                      'customField' => { 'id' => text_field.to_gid.to_s },
                      'value' => 'text value'
                    }
                  ]
                )
              )
            )
          end
        end
      end
    end

    context 'when querying work item type information' do
      include_context 'with work item types request context EE'

      let(:work_item_fields) { "workItemType { #{work_item_type_fields} }" }

      context 'when work item exists at the project level' do
        it 'returns work item type information' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data['workItemType']).to match(
            expected_work_item_type_response(work_item.resource_parent, current_user, work_item.work_item_type).first
          )
        end
      end

      context 'when work item exists at the group level' do
        let(:work_item) { group_work_item }

        it 'returns work item type information' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data['workItemType']).to match(
            expected_work_item_type_response(work_item.resource_parent, current_user, work_item.work_item_type).first
          )
        end
      end
    end

    context 'when accessing sync epic work item' do
      let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
      let(:work_item) { epic.work_item }
      let(:work_item_fields) { "id title" }

      it 'can access sync epic work item' do
        post_graphql(query, current_user: current_user)

        expect(work_item_data['id']).to eq(work_item.to_gid.to_s)
        expect(work_item_data['title']).to eq(work_item.title)
      end
    end
  end
end
