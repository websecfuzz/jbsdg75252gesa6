# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::Gitlab::PreventApprovalByAuthorService,
  feature_category: :compliance_management do
  let_it_be(:project) { create(:project, :in_group) }
  let(:params) { {} }

  let(:service) { described_class.new(project: project, params: params) }

  describe '#execute' do
    context 'when project belongs to user namespace' do
      let_it_be(:project) { create(:project) }

      it 'returns unavailable for user namespace error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Compliance standards adherence is not available for user namespace')
      end
    end

    context 'when group_level_compliance_dashboard feature is not available' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: false)
      end

      it 'returns feature not available error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Compliance standards adherence feature not available')
      end
    end

    context 'when group_level_compliance_dashboard feature is available' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: true)
      end

      context 'when merge request author approval is enabled for the project' do
        it 'sets prevent approval by merge request author check as fail' do
          expect(project).to receive(:merge_requests_author_approval?).and_return(true)

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'prevent_approval_by_merge_request_author',
              standard: 'gitlab'
            )
        end
      end

      context 'when merge request author approval is disabled for the project' do
        it 'sets prevent approval by merge request author check as success' do
          expect(project).to receive(:merge_requests_author_approval?).and_return(false)

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'success',
              check_name: 'prevent_approval_by_merge_request_author',
              standard: 'gitlab'
            )
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        it 'retries in case of race conditions' do
          record_invalid_error = ActiveRecord::RecordInvalid.new(
            create(:compliance_standards_adherence).tap do |project_adherence|
              project_adherence.errors.add(:project, :taken,
                message: "already has this check defined for this standard")
            end
          )

          expect_next_instance_of(::Projects::ComplianceStandards::Adherence) do |project_adherence|
            expect(project_adherence).to receive(:update!).and_raise(record_invalid_error)
          end

          allow_next_instance_of(::Projects::ComplianceStandards::Adherence) do |project_adherence|
            allow(project_adherence).to receive(:update!).and_call_original
          end

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'success',
              check_name: 'prevent_approval_by_merge_request_author',
              standard: 'gitlab'
            )
        end

        it 'does not retry for other scenarios' do
          record_invalid_error = ActiveRecord::RecordInvalid.new(
            create(:compliance_standards_adherence).tap { |adherence| adherence.errors.add(:standard, :blank) }
          )

          expect_next_instance_of(::Projects::ComplianceStandards::Adherence) do |project_adherence|
            expect(project_adherence).to receive(:update!).and_raise(record_invalid_error)
          end

          response = service.execute

          expect(response.status).to eq(:error)
          expect(response.message).to eq("Standard can't be blank")
        end
      end

      context 'when track progress param is set' do
        let(:params) { { 'track_progress' => true } }

        it 'updates progress via StandardsAdherenceChecksTracker' do
          expect(project).to receive(:merge_requests_author_approval?).and_return(true)
          expect_next_instance_of(::ComplianceManagement::StandardsAdherenceChecksTracker,
            project.root_namespace.id) do |tracker|
            expect(tracker).to receive(:update_progress).and_call_original
          end

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'prevent_approval_by_merge_request_author',
              standard: 'gitlab'
            )
        end
      end

      context 'when track progress param is not set' do
        let(:params) { { 'track_progress' => false } }

        it 'does not update progress via StandardsAdherenceChecksTracker' do
          expect(project).to receive(:merge_requests_author_approval?).and_return(true)
          expect(::ComplianceManagement::StandardsAdherenceChecksTracker).not_to receive(:new)

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'prevent_approval_by_merge_request_author',
              standard: 'gitlab'
            )
        end
      end
    end
  end
end
