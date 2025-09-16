# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateArchivedService, feature_category: :vulnerability_management do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :project) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:project)
    end
  end

  describe '#execute' do
    subject(:update_archived) { described_class.new(project).execute }

    context 'when there is no project as input' do
      let(:project) { nil }

      it 'does not raise an error' do
        expect { update_archived }.not_to raise_error
      end
    end

    context 'when there is a project as input' do
      let_it_be_with_reload(:project) { create(:project) }

      context 'when there is no analyzer_status record for the project' do
        it 'does not raise an exception' do
          expect { update_archived }.not_to raise_error
        end
      end

      context 'when there is an analyzer_status record for the project' do
        let!(:analyzer_status) do
          create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success)
        end

        context 'when the project is archived' do
          before do
            project.update!(archived: true)
          end

          it 'sets the analyzer_status record to also be archived' do
            expect { update_archived }
              .to change { analyzer_status.reload.archived }.from(false).to(true)
          end
        end

        context 'when the project is unarchived' do
          before do
            project.update!(archived: false)
            analyzer_status.update!(archived: true)
          end

          it 'sets the analyzer_status record to also not be archived' do
            expect { update_archived }
              .to change { analyzer_status.reload.archived }.from(true).to(false)
          end
        end

        context 'when the project and analyzer_status archived state match' do
          before do
            analyzer_status.update!(archived: true)
            project.update!(archived: true)
          end

          it 'does not change the analyzer_status record archived state' do
            expect { update_archived }
              .not_to change { analyzer_status.reload.archived }
          end
        end
      end
    end
  end
end
