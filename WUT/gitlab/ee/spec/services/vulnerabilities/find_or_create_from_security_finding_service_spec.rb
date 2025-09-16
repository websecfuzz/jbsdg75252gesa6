# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindOrCreateFromSecurityFindingService, '#execute',
  feature_category: :vulnerability_management do
  before do
    stub_licensed_features(security_dashboard: true)
    project.add_developer(user)
  end

  let(:security_finding_uuid) { security_findings.first.uuid }

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:build) { create(:ci_build, :success, name: 'dast', pipeline: pipeline) }
  let_it_be(:artifact) { create(:ee_ci_job_artifact, :dast, job: build) }
  let_it_be(:report) { create(:ci_reports_security_report, pipeline: pipeline, type: :dast) }
  let_it_be(:scan) { create(:security_scan, :latest_successful, scan_type: :dast, build: artifact.job) }
  let_it_be(:security_findings) { [] }
  let_it_be(:state) { 'dismissed' }
  let(:params) { { security_finding_uuid: security_finding_uuid } }
  let(:service) do
    described_class.new(
      project: project,
      current_user: user,
      params: params,
      state: state,
      present_on_default_branch: present_on_default_branch
    )
  end

  let(:present_on_default_branch) { false }

  before_all do
    dast_content = File.read(artifact.file.path)
    Gitlab::Ci::Parsers::Security::Dast.parse!(dast_content, report)
    report.merge!(report)

    security_findings.push(*insert_security_findings)
  end

  subject { service.execute }

  context 'when there is an existing vulnerability for the security finding' do
    let_it_be(:security_finding) { create(:security_finding) }

    context 'when vulnerability is present on default branch' do
      let!(:vulnerability) do
        create(
          :vulnerability,
          project: project,
          findings: [create(:vulnerabilities_finding, uuid: security_finding_uuid)],
          present_on_default_branch: true
        )
      end

      it 'does not create a new Vulnerability' do
        expect { subject }.not_to change(Vulnerability, :count)
      end

      it 'returns the existing Vulnerability' do
        expect(subject).to be_success
        expect(subject.payload[:vulnerability].id).to eq(vulnerability.id)
      end

      it 'does not modify the present_on_default_branch value on the existing vulnerability' do
        expect { subject }.not_to change { vulnerability.reload.present_on_default_branch }
      end

      context 'when the vulnerability state is different from the requested one' do
        it 'updates the state' do
          expect do
            subject

            vulnerability.reload
          end.to change { vulnerability.state }.from("detected").to("dismissed")
             .and change { vulnerability.dismissed_by }.from(nil).to(user)
             .and change { vulnerability.dismissed_at }.from(nil)
        end

        context 'when comment and dismissal_reason is not given' do
          it 'creates a state transition entry', :aggregate_failures do
            expect { subject }.to change(Vulnerabilities::StateTransition, :count).from(0).to(1)
            state_transition = Vulnerabilities::StateTransition.last
            expect(state_transition.from_state).to eq("detected")
            expect(state_transition.to_state).to eq("dismissed")
            expect(state_transition.comment).to be_nil
            expect(state_transition.dismissal_reason).to be_nil
            expect(state_transition.author).to eq(user)
          end
        end

        context 'when comment and dismissal_reason is given', :aggregate_failures do
          let(:comment) { "Dismissal comment" }
          let(:dismissal_reason) { 'false_positive' }

          before do
            params.merge!({ comment: comment, dismissal_reason: dismissal_reason })
          end

          it 'creates a state transition entry with comment and dismissal_reason', :aggregate_failures do
            expect { subject }.to change(Vulnerabilities::StateTransition, :count).from(0).to(1)

            state_transition = Vulnerabilities::StateTransition.last
            expect(state_transition.comment).to eq(comment)
            expect(state_transition.dismissal_reason).to eq(dismissal_reason)
          end

          it 'updates the associated vulnerability_reads dismissal_reason to match the entry', :aggregate_failures do
            expect { subject }.to change(Vulnerabilities::StateTransition, :count).from(0).to(1)

            state_transition = Vulnerabilities::StateTransition.last
            vulnerability_read = vulnerability.vulnerability_read
            expect(vulnerability_read.dismissal_reason).to eq(state_transition.dismissal_reason)
          end
        end

        it 'creates a note' do
          expect { subject }.to change { Note.count }.from(0).to(1)

          note = Note.last

          expect(note.noteable).to eq(project.vulnerabilities.last)
          expect(note.author).to eq(user)
        end
      end

      context 'when the vulnerability state is same with the requested one' do
        before do
          vulnerability.state = 'dismissed'
          vulnerability.save!
        end

        it 'does not update the state' do
          expect { subject }.not_to change { vulnerability.reload.state }
        end

        it 'does not create a state transition entry' do
          expect { subject }.not_to change(Vulnerabilities::StateTransition, :count)
        end

        context 'when vulnerability state is dismissed' do
          let!(:state_transition) do
            create(:vulnerability_state_transition,
              :from_detected,
              :to_dismissed,
              vulnerability: vulnerability,
              comment: nil,
              dismissal_reason: 'used_in_tests')
          end

          let!(:vulnerability_read) do
            vulnerability.vulnerability_read
          end

          let(:comment) { "Dismissal comment" }
          let(:dismissal_reason) { 'false_positive' }
          let(:desired_params) { { comment: comment, dismissal_reason: dismissal_reason } }

          before do
            params.merge!(desired_params)
          end

          it 'updates the existing state transition and vulnerability read with comment and dismissal_reason' do
            expect do
              subject
              state_transition.reload
              vulnerability_read.reload
            end.to change { state_transition.comment }.from(nil).to(comment)
              .and change { state_transition.dismissal_reason }.from('used_in_tests').to(dismissal_reason)
              .and change { vulnerability_read.dismissal_reason }.from(nil).to(dismissal_reason)
          end
        end

        context 'when vulnerability state is dismissed with just a comment' do
          let!(:state_transition) do
            create(:vulnerability_state_transition,
              :from_detected,
              :to_dismissed,
              vulnerability: vulnerability,
              comment: nil,
              dismissal_reason: 'acceptable_risk')
          end

          let(:comment) { "Dismissal comment" }
          let(:desired_params) { { comment: comment } }

          before do
            params.merge!(desired_params)
          end

          it 'updates the existing state transition with comment' do
            expect do
              subject
              state_transition.reload
            end.to change { state_transition.comment }.from(nil).to(comment)
            .and not_change { state_transition.dismissal_reason }.from('acceptable_risk')
          end
        end
      end
    end

    context 'when vulnerability is not present on default branch' do
      let!(:vulnerability) do
        create(
          :vulnerability,
          project: project,
          findings: [create(:vulnerabilities_finding, uuid: security_finding_uuid)],
          present_on_default_branch: false,
          state: :dismissed
        )
      end

      context 'when vulnerability state is dismissed' do
        let!(:state_transition) do
          create(:vulnerability_state_transition,
            :from_detected,
            :to_dismissed,
            vulnerability: vulnerability,
            comment: nil,
            dismissal_reason: 'used_in_tests')
        end

        let(:comment) { "Dismissal comment" }
        let(:dismissal_reason) { 'false_positive' }
        let(:desired_params) { { comment: comment, dismissal_reason: dismissal_reason } }

        before do
          params.merge!(desired_params)
        end

        it 'updates the existing state transition without vulnerability read update' do
          expect do
            subject
            state_transition.reload
          end.to change { state_transition.comment }.from(nil).to(comment)
            .and change { state_transition.dismissal_reason }.from('used_in_tests').to(dismissal_reason)
        end
      end
    end
  end

  context 'when there is no vulnerability for the security finding' do
    let_it_be(:security_finding_uuid) { security_findings.last.uuid }

    it 'creates a new Vulnerability' do
      expect { subject }.to change(Vulnerability, :count).by(1)
    end

    it 'returns a vulnerability with the given state and present_on_default_branch' do
      expect(subject).to be_success
      expect(subject.payload[:vulnerability].state).to eq("dismissed")
      expect(subject.payload[:vulnerability].present_on_default_branch).to eq(present_on_default_branch)
    end
  end

  context 'when there is a error during the vulnerability_finding creation' do
    let_it_be(:security_finding_uuid) { 'invalid-security-finding-uuid' }

    it 'returns an error' do
      expect(subject).to be_error
      expect(subject[:message]).to eq('Security Finding not found')
    end
  end

  context 'when security dashboard feature is disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it 'raises an "access denied" error' do
      expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  def insert_security_findings
    report.findings.map do |finding|
      create(
        :security_finding,
        severity: finding.severity,
        uuid: finding.uuid,
        scan: scan
      )
    end
  end
end
