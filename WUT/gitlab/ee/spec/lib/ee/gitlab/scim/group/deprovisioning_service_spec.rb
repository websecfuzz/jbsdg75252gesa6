# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::Gitlab::Scim::Group::DeprovisioningService, feature_category: :system_access do
  describe '#execute' do
    let(:identity) { create(:scim_identity, active: true) }
    let(:group) { identity.group }
    let(:user) { identity.user }

    let(:service) { described_class.new(identity) }

    context 'when user is successfully removed' do
      before do
        create(:group_member, group: group, user: user, access_level: GroupMember::REPORTER)
      end

      context 'when auditing' do
        let(:request_ip_address) { '192.168.188.69' }
        let(:sign_in_ip) { '175.29.19.1' }

        before do
          allow(::Gitlab::RequestContext.instance).to receive(:client_ip).and_return(request_ip_address)
          user.update! current_sign_in_ip: sign_in_ip
        end

        around do |example|
          RequestStore.begin!
          example.run
          RequestStore.end!
          RequestStore.clear!
        end

        def destroy_audits
          AuditEvent.where %q("details" LIKE '%:event_name: member_destroyed%')
        end

        context 'without admin_audit_log enabled' do
          before do
            stub_licensed_features(admin_audit_log: false)
          end

          it 'audits the access removal without an IP address' do
            expect { service.execute }.to change { destroy_audits.count }.by(1)

            expect(destroy_audits.last.ip_address).to be_nil
          end
        end

        context 'with admin_audit_log enabled' do
          before do
            stub_licensed_features(admin_audit_log: true)
          end

          it "audits the access removal with the request's IP address" do
            expect { service.execute }.to change { destroy_audits.count }.by(1)

            expect(destroy_audits.last.ip_address).to eq(request_ip_address)
          end
        end
      end

      it 'deactivates scim identity' do
        expect { service.execute }.to change { identity.active }.from(true).to(false)
      end

      it 'removes group access' do
        service.execute

        expect(group.all_group_members.pluck(:user_id)).not_to include(user.id)
      end

      it 'returns the successful deprovision message' do
        response = service.execute

        expect(response.message).to include("User #{user.name} was removed from #{group.name}.")
      end

      context 'with a SAML identity' do
        let(:saml_provider) { create(:saml_provider, group: group) }

        before do
          create(:group_saml_identity, user: user, saml_provider: saml_provider)
        end

        it 'preserves the saml identity' do
          expect { service.execute }.not_to change { user.reload.identities.count }
        end
      end
    end

    context 'with minimal access role' do
      before do
        stub_licensed_features(minimal_access_role: true)
        create(:group_member, group: group, user: user, access_level: ::Gitlab::Access::MINIMAL_ACCESS)
      end

      it 'deactivates scim identity' do
        expect { service.execute }.to change { identity.active }.from(true).to(false)
      end

      it 'removes group access' do
        service.execute

        expect(group.all_group_members.pluck(:user_id)).not_to include(user.id)
      end

      it 'returns the successful deprovision message' do
        response = service.execute

        expect(response.message).to include("User #{user.name} was removed from #{group.name}.")
      end
    end

    context 'when user is not successfully removed' do
      context 'when user is the last owner' do
        before do
          create(:group_member, group: group, user: user, access_level: GroupMember::OWNER)
        end

        it 'does not remove the last owner' do
          service.execute

          expect(identity.group.members.pluck(:user_id)).to include(user.id)
        end

        it 'returns the last group owner error' do
          response = service.execute

          expect(response.error?).to be true
          expect(response.errors).to include(
            "Could not remove #{user.name} from #{group.name}. Cannot remove last group owner."
          )
        end
      end

      context 'when user is not a group member' do
        it 'does not change group membership when the user is not a member' do
          expect { service.execute }.not_to change { group.members.count }
        end

        it 'deactivates scim identity' do
          expect { service.execute }.to change { identity.active }.from(true).to(false)
        end
      end
    end
  end
end
