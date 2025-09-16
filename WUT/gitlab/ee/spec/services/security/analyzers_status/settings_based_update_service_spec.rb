# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::SettingsBasedUpdateService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be_with_reload(:project1) { create(:project, group: group) }
  let_it_be_with_reload(:project2) { create(:project, group: group) }
  let_it_be_with_reload(:project3) { create(:project, group: group) }

  let(:project_ids) { [project1.id, project2.id] }
  let(:analyzer_type) { :secret_detection }
  let(:service) { described_class.new(project_ids, analyzer_type) }

  describe '.execute' do
    it 'creates a new instance and calls execute' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(project_ids, analyzer_type)
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when group_settings_based_update_worker feature flag is disabled for some root ancestors' do
      let_it_be(:another_root_group) { create(:group) }
      let_it_be(:another_group) { create(:group, parent: another_root_group) }
      let_it_be_with_reload(:project_with_disabled_ff) { create(:project, group: another_group) }

      let(:project_ids) { [project1.id, project2.id, project_with_disabled_ff.id] }

      before do
        stub_feature_flags(group_settings_based_update_worker: root_group)

        project1.security_setting.update!(secret_push_protection_enabled: true)
        project2.security_setting.update!(secret_push_protection_enabled: true)
        project_with_disabled_ff.security_setting.update!(secret_push_protection_enabled: true)
      end

      it 'only processes projects whose root ancestor has the feature flag enabled' do
        expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated

        expect(Security::AnalyzerProjectStatus
          .find_by(project: project1, analyzer_type: :secret_detection_secret_push_protection)).to be_present
        expect(Security::AnalyzerProjectStatus
          .find_by(project: project2, analyzer_type: :secret_detection_secret_push_protection)).to be_present

        expect(Security::AnalyzerProjectStatus
          .find_by(project: project_with_disabled_ff, analyzer_type: :secret_detection)).to be_nil
        expect(Security::AnalyzerProjectStatus
          .find_by(project: project_with_disabled_ff, analyzer_type: :secret_detection_secret_push_protection))
          .to be_nil
      end
    end

    context 'when post_pipeline_analyzer_status_updates feature flag is enabled' do
      context 'when analyzer_type is not supported' do
        let(:analyzer_type) { :unsupported_analyzer }

        it 'does not call upsert_analyzers_statuses' do
          expect(service).not_to receive(:upsert_analyzers_statuses)
          execute
        end
      end

      context 'when project_ids is empty' do
        let(:project_ids) { [] }

        it 'does not call upsert_analyzers_statuses' do
          expect(service).not_to receive(:upsert_analyzers_statuses)
          execute
        end
      end

      context 'when project_ids is nil' do
        let(:project_ids) { nil }

        it 'does not call upsert_analyzers_statuses' do
          expect(service).not_to receive(:upsert_analyzers_statuses)
          execute
        end
      end

      shared_examples 'analyzer behavior' do |analyzer_type_sym, setting_field, expected_analyzer_type|
        let(:analyzer_type) { analyzer_type_sym }

        context 'when projects have security settings' do
          context 'when both settings are enabled (true)' do
            before do
              project1.security_setting.update!(setting_field => true)
              project2.security_setting.update!(setting_field => true)
            end

            it 'creates analyzer status records with success status' do
              expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated
              project1_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project1, analyzer_type: expected_analyzer_type)
              project2_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project2, analyzer_type: expected_analyzer_type)

              expect(project1_status).to have_attributes(status: 'success', archived: false, build_id: nil)
              expect(project2_status).to have_attributes(status: 'success', archived: false, build_id: nil)
            end
          end

          context 'when settings are mixed (true and false)' do
            before do
              project1.security_setting.update!(setting_field => true)
              project2.security_setting.update!(setting_field => false)
            end

            it 'creates analyzer status records with different statuses' do
              expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated
              project1_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project1, analyzer_type: expected_analyzer_type)
              project2_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project2, analyzer_type: expected_analyzer_type)

              expect(project1_status).to have_attributes(status: 'success', archived: false, build_id: nil)
              expect(project2_status).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
            end
          end

          context 'when both settings are disabled (false)' do
            before do
              project1.security_setting.update!(setting_field => false)
              project2.security_setting.update!(setting_field => false)
            end

            it 'creates analyzer status records with not_configured status' do
              expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated
              project1_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project1, analyzer_type: expected_analyzer_type)
              project2_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project2, analyzer_type: expected_analyzer_type)

              expect(project1_status).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
              expect(project2_status).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
            end
          end

          context 'when project is archived' do
            before do
              project1.update!(archived: true)
              project1.security_setting.update!(setting_field => true)
              project2.security_setting.update!(setting_field => false)
            end

            it 'includes archived status in the analyzer status' do
              execute

              project1_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project1, analyzer_type: expected_analyzer_type)
              project2_status = Security::AnalyzerProjectStatus
                                  .find_by(project: project2, analyzer_type: expected_analyzer_type)

              expect(project1_status).to have_attributes(status: 'success', archived: true)
              expect(project2_status).to have_attributes(status: 'not_configured', archived: false)
            end
          end
        end

        context 'when updating existing analyzer status records' do
          let!(:existing_record1) do
            create(:analyzer_project_status, project: project1, analyzer_type: expected_analyzer_type, status: :failed)
          end

          let!(:existing_record2) do
            create(:analyzer_project_status, project: project2, analyzer_type: expected_analyzer_type, status: :success)
          end

          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'updates existing records without creating new ones' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # only aggregated types created

            expect(existing_record1.reload).to have_attributes(status: 'success', archived: false, build_id: nil)
            expect(existing_record2.reload).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
          end
        end

        context 'when some projects have existing records and others do not' do
          let!(:existing_record) do
            create(:analyzer_project_status, project: project1, analyzer_type: expected_analyzer_type, status: :failed)
          end

          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'updates existing record and creates new record' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(3) # 1 setting + 2 aggregated

            expect(existing_record.reload).to have_attributes(status: 'success')

            new_record = Security::AnalyzerProjectStatus
              .find_by(project: project2, analyzer_type: expected_analyzer_type)
            expect(new_record).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
          end
        end

        context 'when aggregated type already exists with matching status' do
          let!(:existing_setting_record) do
            create(:analyzer_project_status, project: project1, analyzer_type: expected_analyzer_type, status: :success)
          end

          let!(:existing_aggregated_record) do
            aggregated_type =
              case expected_analyzer_type
              when :secret_detection_secret_push_protection
                :secret_detection
              when :container_scanning_for_registry
                :container_scanning
              end

            create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :success)
          end

          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'updates the aggregated record when status matches' do
            travel_to(1.minute.from_now) do
              expect { execute }.to change { existing_aggregated_record.reload.updated_at }
            end
          end

          it 'creates status records for non-existing type' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # 1 setting + 1 aggregated
          end
        end

        context 'when aggregated type exists with different status' do
          let!(:existing_setting_record) do
            create(:analyzer_project_status,
              project: project1, analyzer_type: expected_analyzer_type, status: :not_configured)
          end

          let!(:existing_aggregated_record) do
            aggregated_type =
              case expected_analyzer_type
              when :secret_detection_secret_push_protection
                :secret_detection
              when :container_scanning_for_registry
                :container_scanning
              end

            create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :not_configured)
          end

          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'updates the aggregated record when status differs' do
            execute

            expect(existing_aggregated_record.reload)
              .to have_attributes(status: 'success', archived: false, build_id: nil)
          end

          it 'creates the correct number of records' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # 1 setting + 1 aggregated
          end
        end

        context 'when aggregated type exists but other type has higher priority' do
          let!(:existing_setting_record) do
            create(:analyzer_project_status,
              project: project1, analyzer_type: expected_analyzer_type, status: :not_configured)
          end

          let!(:existing_pipeline_record) do
            other_type =
              case expected_analyzer_type
              when :secret_detection_secret_push_protection
                :secret_detection_pipeline_based
              when :container_scanning_for_registry
                :container_scanning_pipeline_based
              end

            create(:analyzer_project_status, project: project1, analyzer_type: other_type, status: :failed)
          end

          let!(:existing_aggregated_record) do
            aggregated_type =
              case expected_analyzer_type
              when :secret_detection_secret_push_protection
                :secret_detection
              when :container_scanning_for_registry
                :container_scanning
              end

            create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :failed)
          end

          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'does not update aggregated record when other type has higher priority' do
            original_updated_at = existing_aggregated_record.updated_at

            travel_to(1.minute.from_now) do
              execute

              expect(existing_aggregated_record.reload.updated_at.to_i).to eq(original_updated_at.to_i)
              expect(existing_aggregated_record.reload.status).to eq('failed')
            end
          end
        end
      end

      describe 'secret_detection analyzer' do
        include_examples 'analyzer behavior',
          :secret_detection,
          :secret_push_protection_enabled,
          :secret_detection_secret_push_protection
      end

      describe 'container_scanning analyzer' do
        include_examples 'analyzer behavior',
          :container_scanning, :container_scanning_for_registry_enabled, :container_scanning_for_registry
      end

      context 'when projects do not have security settings' do
        let_it_be_with_reload(:project_without_settings) { create(:project, group: group) }
        let_it_be(:project_ids) { [project_without_settings.id] }

        before do
          project_without_settings.security_setting&.delete
        end

        it 'creates records with not_configured status' do
          expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # 1 setting + 1 aggregated

          setting_record = Security::AnalyzerProjectStatus.find_by(
            project: project_without_settings, analyzer_type: :secret_detection_secret_push_protection
          )
          aggregated_record = Security::AnalyzerProjectStatus.find_by(
            project: project_without_settings, analyzer_type: :secret_detection)

          expect(setting_record).to have_attributes(status: 'not_configured')
          expect(aggregated_record).to have_attributes(status: 'not_configured')
        end
      end
    end

    context 'when projects have status changes' do
      before do
        project1.security_setting.update!(secret_push_protection_enabled: true)
        project2.security_setting.update!(secret_push_protection_enabled: false)
      end

      it 'calls DiffsService with correct analyzers_statuses hash structure' do
        expected_hash_structure = hash_including(
          project1 => hash_including(
            secret_detection_secret_push_protection: hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success
            ),
            secret_detection: hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection,
              status: :success
            )
          ),
          project2 => hash_including(
            secret_detection_secret_push_protection: hash_including(
              project_id: project2.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :not_configured
            ),
            secret_detection: hash_including(
              project_id: project2.id,
              analyzer_type: :secret_detection,
              status: :not_configured
            )
          )
        )

        expect(Security::AnalyzersStatus::DiffsService).to receive(:new).with(expected_hash_structure).and_call_original

        execute
      end

      it 'calls AncestorsUpdateService with correct namespace diff structure when there are changes' do
        create(:analyzer_project_status, project: project1, analyzer_type: :secret_detection_secret_push_protection,
          status: :failed)

        create(:analyzer_project_status, project: project1, analyzer_type: :secret_detection, status: :failed)

        expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
          .to receive(:execute).with(hash_including(
            namespace_id: group.id,
            traversal_ids: group.traversal_ids,
            diff: hash_including(
              secret_detection_secret_push_protection: hash_including('success' => 1, 'failed' => -1),
              secret_detection: hash_including('success' => 1, 'failed' => -1)
            )))

        execute
      end
    end

    context 'with multiple namespaces' do
      let_it_be(:another_root_group) { create(:group) }
      let_it_be(:another_group) { create(:group, parent: another_root_group) }
      let_it_be_with_reload(:project_in_another_namespace) { create(:project, group: another_group) }

      let(:project_ids) { [project1.id, project_in_another_namespace.id] }

      before do
        stub_feature_flags(post_pipeline_analyzer_status_updates: [root_group, another_root_group])
        project1.security_setting.update!(secret_push_protection_enabled: true)
        project_in_another_namespace.security_setting.update!(secret_push_protection_enabled: false)
      end

      it 'calls AncestorsUpdateService once for each namespace' do
        expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
          .to receive(:execute).with(hash_including(namespace_id: group.id)).once

        expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService).to receive(:execute)
          .with(hash_including(namespace_id: another_group.id)).once

        execute
      end
    end

    context 'without an aggregated status for some projects' do
      before do
        project1.security_setting.update!(secret_push_protection_enabled: true)

        create(:analyzer_project_status, project: project1, analyzer_type: :secret_detection_pipeline_based,
          status: :success)
      end

      it 'excludes nil aggregated statuses from the hash structure' do
        expected_hash_structure = hash_including(
          project1 => hash_including(
            secret_detection_secret_push_protection: hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success
            )
          )
        )

        expect(Security::AnalyzersStatus::DiffsService).to receive(:new).with(expected_hash_structure).and_call_original

        execute
      end
    end
  end

  describe '#initialize' do
    context 'when project_ids count is within limit' do
      let(:project_ids) { (1..described_class::MAX_PROJECT_IDS).to_a }

      it 'does not raise an error' do
        expect { described_class.new(project_ids, analyzer_type) }.not_to raise_error
      end
    end

    context 'when project_ids count exceeds maximum limit' do
      let(:project_ids) { (1..(described_class::MAX_PROJECT_IDS + 1)).to_a }

      it 'raises TooManyProjectIdsError with correct message' do
        expect { described_class.new(project_ids, analyzer_type) }
          .to raise_error(Security::AnalyzersStatus::SettingsBasedUpdateService::TooManyProjectIdsError,
            "Cannot update analyzer statuses of more than #{described_class::MAX_PROJECT_IDS} projects")
      end
    end
  end
end
