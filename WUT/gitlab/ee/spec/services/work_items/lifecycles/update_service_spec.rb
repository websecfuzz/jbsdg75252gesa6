#  frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Lifecycles::UpdateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { WorkItems::Statuses::SystemDefined::Lifecycle.all.first }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

  let(:params) do
    {
      id: system_defined_lifecycle.to_gid,
      statuses: [
        status_params_for(system_defined_lifecycle.default_open_status),
        status_params_for(system_defined_in_progress_status),
        status_params_for(system_defined_lifecycle.default_closed_status),
        status_params_for(system_defined_wont_do_status),
        status_params_for(system_defined_lifecycle.default_duplicate_status)
      ],
      default_open_status_index: 0,
      default_closed_status_index: 2,
      default_duplicate_status_index: 4
    }
  end

  subject(:result) do
    described_class.new(container: group, current_user: user, params: params).execute
  end

  before do
    stub_licensed_features(work_item_status: true, board_status_lists: true)
  end

  RSpec.shared_examples 'creates custom lifecycle' do
    it 'creates custom lifecycle' do
      expect { result }.to change { WorkItems::Statuses::Custom::Lifecycle.count }.by(1)

      expect(lifecycle).to have_attributes(
        name: 'Default',
        namespace: group,
        created_by: user
      )
    end
  end

  RSpec.shared_examples 'does not create custom lifecycle' do
    it 'does not create custom lifecycle' do
      expect { result }.not_to change { WorkItems::Statuses::Custom::Lifecycle.count }
    end
  end

  RSpec.shared_examples 'sets default statuses correctly' do
    it 'sets default statuses correctly' do
      expect(lifecycle.default_open_status.name).to eq(system_defined_lifecycle.default_open_status.name)
      expect(lifecycle.default_closed_status.name).to eq(system_defined_lifecycle.default_closed_status.name)
      expect(lifecycle.default_duplicate_status.name).to eq(system_defined_lifecycle.default_duplicate_status.name)
    end
  end

  RSpec.shared_examples 'removes custom statuses' do
    it 'removes custom statuses' do
      expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(-1)
      expect(lifecycle.statuses.pluck(:name)).not_to include(custom_status.name)
      expect(lifecycle.statuses.count).to eq(3)
    end
  end

  RSpec.shared_examples 'reorders custom statuses' do
    it 'reorders custom statuses' do
      expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
        custom_lifecycle.default_open_status.name,
        custom_lifecycle.default_closed_status.name,
        custom_lifecycle.default_duplicate_status.name
      ])
    end
  end

  RSpec.shared_examples 'returns validation error' do
    it 'returns validation error' do
      expect(result).to be_error
      expect(result.message).to eq(expected_error_message)
    end
  end

  describe '#execute' do
    let(:lifecycle) { result.payload[:lifecycle] }

    context 'when custom lifecycle does not exist' do
      it_behaves_like 'creates custom lifecycle'
      it_behaves_like 'sets default statuses correctly'

      it 'creates custom statuses from system-defined statuses' do
        expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(5)

        expect(lifecycle.statuses.pluck(:name)).to contain_exactly(
          system_defined_lifecycle.default_open_status.name,
          system_defined_in_progress_status.name,
          system_defined_lifecycle.default_closed_status.name,
          system_defined_wont_do_status.name,
          system_defined_lifecycle.default_duplicate_status.name
        )
        expect(lifecycle.statuses.count).to eq(5)
      end

      it 'preserves the status mapping' do
        expect(lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
          .to contain_exactly(1, 2, 3, 4, 5)
      end

      context 'when only some of the system-defined statuses are provided' do
        let(:params) do
          {
            id: system_defined_lifecycle.to_gid,
            statuses: [
              status_params_for(system_defined_lifecycle.default_open_status),
              status_params_for(system_defined_lifecycle.default_closed_status),
              status_params_for(system_defined_lifecycle.default_duplicate_status)
            ],
            default_open_status_index: 0,
            default_closed_status_index: 1,
            default_duplicate_status_index: 2
          }
        end

        it_behaves_like 'creates custom lifecycle'
        it_behaves_like 'sets default statuses correctly'

        it 'creates custom statuses from system-defined statuses' do
          expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(3)

          expect(lifecycle.statuses.pluck(:name)).to contain_exactly(
            system_defined_lifecycle.default_open_status.name,
            system_defined_lifecycle.default_closed_status.name,
            system_defined_lifecycle.default_duplicate_status.name
          )
          expect(lifecycle.statuses.count).to eq(3)
        end

        it 'preserves the status mapping' do
          expect(lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
            .to contain_exactly(1, 3, 5)
        end

        it 'tracks deletion events for the missing statuses' do
          expect { result }
            .to trigger_internal_events('delete_custom_status_in_group_settings')
            .with(user: user, namespace: group, additional_properties: { label: eq('in_progress').or(eq('canceled')) })
            .exactly(2).times
        end

        context 'when some system-defined status params are changed' do
          let(:updated_status_params) { params[:statuses][1] }

          shared_examples 'triggers events for converted statuses with changes' do
            it 'tracks update events for the updated statuses' do
              expect { result }
                .to trigger_internal_events('update_custom_status_in_group_settings')
                .with(user: user, namespace: group, additional_properties: {
                  label: updated_status_params[:category].to_s
                })
            end
          end

          context 'when name is changed' do
            before do
              updated_status_params[:name] = 'New name'
            end

            it_behaves_like 'triggers events for converted statuses with changes'
          end

          context 'when color is changed' do
            before do
              updated_status_params[:color] = '#000000'
            end

            it_behaves_like 'triggers events for converted statuses with changes'
          end

          context 'when description is changed' do
            before do
              updated_status_params[:description] = 'Some description'
            end

            it_behaves_like 'triggers events for converted statuses with changes'
          end

          context 'when description is set to empty string' do
            before do
              updated_status_params[:description] = ''
            end

            it 'does not trigger update event' do
              expect { result }
                .not_to trigger_internal_events('update_custom_status_in_group_settings')
            end
          end
        end

        context 'when there are board lists using the system-defined status' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:project) { create(:project, group: group) }

          let!(:group_list) do
            create(
              :status_list,
              board: create(:board, group: group),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          let!(:subgroup_list) do
            create(
              :status_list,
              board: create(:board, group: subgroup),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          let!(:project_list) do
            create(
              :status_list,
              board: create(:board, project: project),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          let!(:other_system_defined_list) do
            create(
              :status_list,
              board: create(:board, project: project),
              system_defined_status_identifier: build(:work_item_system_defined_status, :to_do).id
            )
          end

          let!(:other_project_list) do
            create(
              :status_list,
              board: create(:board),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          it 'removes board lists using the omitted statuses' do
            expect { result }.to change { List.count }.by(-3)

            expect { group_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { subgroup_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { project_list.reload }.to raise_error(ActiveRecord::RecordNotFound)

            expect(other_system_defined_list.reload).to be_present
            expect(other_project_list.reload).to be_present
          end
        end

        context 'when trying to exclude a status in use' do
          let(:work_item) { create(:work_item, namespace: group) }
          let!(:current_status) do
            create(:work_item_current_status, work_item: work_item,
              system_defined_status: system_defined_in_progress_status)
          end

          let(:expected_error_message) do
            "Cannot delete status '#{system_defined_in_progress_status.name}' because it is in use"
          end

          it_behaves_like 'does not create custom lifecycle'
          it_behaves_like 'returns validation error'
        end

        context 'when trying to exclude a default status' do
          let(:params) do
            {
              id: system_defined_lifecycle.to_gid,
              statuses: [
                status_params_for(system_defined_lifecycle.default_closed_status),
                status_params_for(system_defined_lifecycle.default_duplicate_status)
              ]
            }
          end

          let(:expected_error_message) do
            "Cannot delete status '#{system_defined_lifecycle.default_open_status.name}' " \
              "because it is marked as a default status"
          end

          it_behaves_like 'does not create custom lifecycle'
          it_behaves_like 'returns validation error'
        end
      end

      context 'when attempting to exceed status limit' do
        let(:params) do
          statuses_array = [
            status_params_for(system_defined_lifecycle.default_open_status),
            status_params_for(system_defined_in_progress_status),
            status_params_for(system_defined_lifecycle.default_closed_status),
            status_params_for(system_defined_wont_do_status),
            status_params_for(system_defined_lifecycle.default_duplicate_status)
          ]

          26.times do |i|
            statuses_array << {
              name: "Custom To Do #{i + 1}",
              color: '#737278',
              description: nil,
              category: 'to_do'
            }
          end

          {
            id: system_defined_lifecycle.to_gid,
            statuses: statuses_array,
            default_open_status_index: 0,
            default_closed_status_index: 2,
            default_duplicate_status_index: 4
          }
        end

        it 'returns validation error' do
          expect(result).to be_error
          expect(result.message).to include('Lifecycle can only have a maximum of 30 statuses')
        end
      end
    end

    context 'when custom lifecycle exists' do
      let!(:custom_lifecycle) do
        create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: group)
      end

      context 'when system-defined lifecycle is provided' do
        it_behaves_like 'does not create custom lifecycle'

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Invalid lifecycle type. Custom lifecycle already exists.')
        end
      end

      context 'when custom lifecycle is provided' do
        let(:params) do
          {
            id: custom_lifecycle.to_gid,
            statuses: [
              status_params_for(custom_lifecycle.default_open_status),
              status_params_for(custom_lifecycle.default_closed_status),
              status_params_for(custom_lifecycle.default_duplicate_status),
              {
                name: 'Ready for development',
                color: '#737278',
                description: nil,
                category: 'to_do'
              },
              {
                name: 'Complete',
                color: '#108548',
                description: nil,
                category: 'done'
              }
            ],
            default_open_status_index: 0,
            default_closed_status_index: 1,
            default_duplicate_status_index: 2
          }
        end

        context 'when statuses are added' do
          it 'adds custom statuses' do
            expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(2)

            expect(lifecycle.statuses.pluck(:name)).to include('Ready for development', 'Complete')

            expect(lifecycle.statuses.count).to eq(5)
          end

          it 'tracks creation events for the new statuses' do
            expect { result }
              .to trigger_internal_events('create_custom_status_in_group_settings')
              .with(user: user, namespace: group, additional_properties: { label: eq('to_do').or(eq('done')) })
              .exactly(2).times
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              custom_lifecycle.default_open_status.name,
              'Ready for development',
              custom_lifecycle.default_closed_status.name,
              'Complete',
              custom_lifecycle.default_duplicate_status.name
            ])
          end

          context 'when other root namespace exists' do
            let_it_be(:other_group) { create(:group) }

            let!(:other_custom_lifecycle) do
              create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: other_group)
            end

            let(:params) do
              {
                id: custom_lifecycle.to_gid,
                statuses: [
                  status_params_for(custom_lifecycle.default_open_status),
                  status_params_for(custom_lifecycle.default_closed_status),
                  status_params_for(custom_lifecycle.default_duplicate_status),
                  status_params_for(other_custom_lifecycle.default_open_status)
                ],
                default_open_status_index: 0,
                default_closed_status_index: 1,
                default_duplicate_status_index: 2
              }
            end

            shared_examples 'returns error and does not change data' do
              it_behaves_like 'returns validation error'

              it 'does not add status from other lifecycle' do
                expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }

                expect(custom_lifecycle.statuses.count).to eq(3)
              end
            end

            context 'when provided lifecycle belongs to other root namespace' do
              before do
                params[:id] = other_custom_lifecycle.to_gid
              end

              let(:expected_error_message) do
                "You don't have permission to update this lifecycle."
              end

              it_behaves_like 'returns error and does not change data'
            end

            context 'when provided status belongs to other root namespace' do
              let(:expected_error_message) do
                "Status '#{other_custom_lifecycle.default_open_status.name}' doesn't belong to this namespace."
              end

              it_behaves_like 'returns error and does not change data'
            end
          end
        end

        context 'when statuses are updated' do
          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(custom_lifecycle.default_open_status).merge(
                  name: 'Updated To Do',
                  description: 'Updated description'
                ),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          it 'updates custom status attributes' do
            expect(lifecycle.default_open_status).to have_attributes(
              name: 'Updated To Do',
              description: 'Updated description',
              updated_by: user
            )
          end

          it 'tracks update events for the updated statuses' do
            expect { result }
              .to trigger_internal_events('update_custom_status_in_group_settings')
              .with(user: user, namespace: group, additional_properties: { label: 'to_do' })
          end

          it 'preserves the status mapping' do
            expect(lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
              .to contain_exactly(1, 3, 5)
          end

          context 'when updating status without providing ID' do
            let(:params) do
              {
                id: custom_lifecycle.to_gid,
                statuses: [
                  {
                    name: custom_lifecycle.default_open_status.name,
                    color: custom_lifecycle.default_open_status.color,
                    description: 'Updated description',
                    category: custom_lifecycle.default_open_status.category
                  },
                  status_params_for(custom_lifecycle.default_closed_status),
                  status_params_for(custom_lifecycle.default_duplicate_status)
                ],
                default_open_status_index: 0,
                default_closed_status_index: 1,
                default_duplicate_status_index: 2
              }
            end

            it 'updates custom status attributes' do
              expect(lifecycle.default_open_status).to have_attributes(
                description: 'Updated description',
                updated_by: user
              )
            end
          end
        end

        context 'when default statuses are updated' do
          let(:new_open_status) { create(:work_item_custom_status, namespace: group) }
          let!(:new_open_lifecycle_status) do
            create(:work_item_custom_lifecycle_status,
              lifecycle: custom_lifecycle, status: new_open_status, namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(new_open_status),
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 2,
              default_duplicate_status_index: 3
            }
          end

          it 'updates the default status' do
            expect(lifecycle.default_open_status).to eq(new_open_status)
            expect(lifecycle.updated_by).to eq(user)
          end
        end

        context 'when statuses are removed' do
          let!(:custom_lifecycle_status) do
            create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: custom_status,
              namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          context 'when removing status without mapping' do
            let(:custom_status) do
              create(:work_item_custom_status, :without_mapping, name: 'Ready for development', namespace: group)
            end

            it_behaves_like 'removes custom statuses'
            it_behaves_like 'reorders custom statuses'

            context 'when trying to remove a status in use' do
              let(:work_item) { create(:work_item, namespace: group) }
              let!(:current_status) do
                create(:work_item_current_status, work_item: work_item, custom_status: custom_status)
              end

              let(:expected_error_message) do
                "Cannot delete status '#{custom_status.name}' because it is in use"
              end

              it_behaves_like 'returns validation error'
            end

            context 'when trying to remove a default status' do
              let(:params) do
                {
                  id: custom_lifecycle.to_gid.to_s,
                  statuses: [
                    status_params_for(custom_lifecycle.default_closed_status),
                    status_params_for(custom_lifecycle.default_duplicate_status)
                  ]
                }
              end

              it 'returns an error' do
                custom_lifecycle_status.destroy!
                custom_lifecycle.update!(default_open_status: custom_status)

                expect(result).to be_error
                expect(result.message).to eq(
                  "Cannot delete status '#{custom_status.name}' " \
                    "because it is marked as a default status"
                )
              end
            end
          end

          context 'when removing status with mapping' do
            let(:custom_status) do
              create(:work_item_custom_status, :in_progress, name: 'Ready for dev', namespace: group)
            end

            it_behaves_like 'removes custom statuses'
            it_behaves_like 'reorders custom statuses'

            context 'when there are board lists using the mapped status' do
              let_it_be(:subgroup) { create(:group, parent: group) }
              let_it_be(:project) { create(:project, group: group) }

              let!(:group_list) do
                create(
                  :status_list,
                  board: create(:board, group: group),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              let!(:subgroup_list) do
                create(
                  :status_list,
                  board: create(:board, group: subgroup),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              let!(:project_list) do
                create(
                  :status_list,
                  board: create(:board, project: project),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              let!(:custom_status_list) do
                create(
                  :status_list,
                  :with_custom_status,
                  board: create(:board, project: project),
                  custom_status: create(:work_item_custom_status, :triage, namespace: group)
                )
              end

              let!(:other_project_list) do
                create(
                  :status_list,
                  board: create(:board),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              it 'removes the mapped board lists' do
                expect { result }.to change { List.count }.by(-3)

                expect { group_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
                expect { subgroup_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
                expect { project_list.reload }.to raise_error(ActiveRecord::RecordNotFound)

                expect(custom_status_list.reload).to be_present
                expect(other_project_list.reload).to be_present
              end
            end

            context 'when trying to remove a status in explicit use' do
              let(:work_item) { create(:work_item, namespace: group) }
              let!(:current_status) do
                create(:work_item_current_status, work_item: work_item, custom_status: custom_status)
              end

              let(:expected_error_message) do
                "Cannot delete status '#{custom_status.name}' because it is in use"
              end

              it_behaves_like 'returns validation error'
            end

            context 'when trying to remove a status in implicit use' do
              let!(:work_item) { create(:work_item, namespace: group) }
              let(:new_default_status) { create(:work_item_custom_status, :triage, namespace: group) }
              let(:expected_error_message) do
                "Cannot delete status 'To do' because it is in use"
              end

              before do
                custom_lifecycle.default_open_status.update!(name: "To do")
                custom_lifecycle.update!(default_open_status: new_default_status)
              end

              it_behaves_like 'returns validation error'
            end

            context 'when trying to remove a default status' do
              let(:params) do
                {
                  id: custom_lifecycle.to_gid.to_s,
                  statuses: [
                    status_params_for(custom_lifecycle.default_closed_status),
                    status_params_for(custom_lifecycle.default_duplicate_status)
                  ]
                }
              end

              it 'returns an error' do
                custom_lifecycle_status.destroy!
                custom_lifecycle.update!(default_open_status: custom_status)

                expect(result).to be_error
                expect(result.message).to eq(
                  "Cannot delete status '#{custom_status.name}' " \
                    "because it is marked as a default status"
                )
              end
            end
          end
        end

        context 'when statuses are reordered' do
          let(:existing_in_progress_status) do
            create(:work_item_custom_status, name: 'In Progress', namespace: group, category: :in_progress)
          end

          let!(:lifecycle_status) do
            create(:work_item_custom_lifecycle_status,
              lifecycle: custom_lifecycle, status: existing_in_progress_status, namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                {
                  name: 'Ready for development',
                  color: '#737278',
                  description: nil,
                  category: 'to_do'
                },
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(existing_in_progress_status),
                {
                  name: 'Complete',
                  color: '#108548',
                  description: nil,
                  category: 'done'
                },
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 3,
              default_duplicate_status_index: 5
            }
          end

          before do
            custom_lifecycle.default_open_status.name = "To do"
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              'Ready for development',
              'To do',
              'In Progress',
              'Complete',
              custom_lifecycle.default_closed_status.name,
              custom_lifecycle.default_duplicate_status.name
            ])
          end
        end

        context 'when attempting to exceed status limit' do
          let(:params) do
            statuses_array = [
              status_params_for(custom_lifecycle.default_open_status),
              status_params_for(custom_lifecycle.default_closed_status),
              status_params_for(custom_lifecycle.default_duplicate_status)
            ]

            28.times do |i|
              statuses_array << {
                name: "Custom To Do #{i + 1}",
                color: '#737278',
                description: nil,
                category: 'to_do'
              }
            end

            {
              id: custom_lifecycle.to_gid,
              statuses: statuses_array,
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          it 'returns validation error' do
            expect(result).to be_error
            expect(result.message).to include('Lifecycle can only have a maximum of 30 statuses')
          end
        end
      end
    end

    context 'when work_item_status_feature_flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it 'returns feature not available error' do
        expect(result).to be_error
        expect(result.message).to eq('This feature is currently behind a feature flag, and it is not available.')
      end
    end

    context 'when user is not authorized' do
      let(:user) { create(:user, guest_of: group) }

      it 'returns authorization error' do
        expect(result).to be_error
        expect(result.message).to eq("You don't have permission to update a lifecycle for this namespace.")
      end
    end
  end

  private

  def status_params_for(status)
    {
      id: status.to_global_id,
      name: status.name,
      color: status.color,
      description: status.description,
      category: status.category
    }
  end
end
