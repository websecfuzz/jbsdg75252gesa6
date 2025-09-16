# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::ComplianceViolationsService, feature_category: :compliance_management do
  let_it_be(:group) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:author) { create(:user) }
  let_it_be(:compliance_violation) { create(:project_compliance_violation, namespace: group, project: project) }

  let(:service) { described_class.new(noteable: compliance_violation, container: project, author: author) }

  describe '#change_violation_status' do
    subject(:create_note) { service.change_violation_status }

    where(:status, :humanized_status) do
      [
        ['detected', 'Detected'],
        ['in_review', 'In review'],
        ['resolved', 'Resolved'],
        ['dismissed', 'Dismissed']
      ]
    end

    with_them do
      before do
        compliance_violation.update!(status: status)
      end

      it 'creates a system note with the correct attributes' do
        expect { create_note }.to change { Note.count }.by(1)

        created_note = Note.last
        expect(created_note.noteable).to eq(compliance_violation)
        expect(created_note.project).to eq(project)
        expect(created_note.author).to eq(author)
        expect(created_note.note).to eq("changed status to #{humanized_status}")
        expect(created_note.system).to be_truthy
      end
    end
  end
end
