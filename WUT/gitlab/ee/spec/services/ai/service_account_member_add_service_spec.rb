# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ServiceAccountMemberAddService, feature_category: :duo_workflow do
  let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let_it_be(:project) { create(:project) }
  let(:service) { described_class.new(project, service_account) }

  describe '#execute' do
    context 'when the service account is not a member of the project' do
      it 'adds the service account as a developer' do
        expect { service.execute }.to change { project.members.count }.by(1)

        member = project.members.last
        expect(member.user_id).to eq(service_account.id)
        expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to be_a(ProjectMember)
      end
    end

    context 'when the service account is already a member of the project' do
      before_all do
        project.add_developer(service_account)
      end

      it 'does not add a new membership' do
        expect { service.execute }.not_to change { project.members.count }
      end

      it 'returns a success response with a message' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq("Membership already exists. Nothing to do.")
      end
    end

    context 'when the service account is not found' do
      let(:service_account) { nil }

      it 'does not add a new membership' do
        expect { service.execute }.not_to change { project.members.count }
      end

      it 'returns an error response with a message' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Service account user not found")
      end
    end

    context 'when adding project member returns error' do
      before do
        allow_next_instance_of(ProjectMember) do |member|
          allow(member).to receive(:persisted?).and_return(false)
        end
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Failed to add service account as developer")
      end
    end
  end
end
