# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitAuditEvent, feature_category: :source_code_management do
  let_it_be(:player) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project) }

  subject { described_class.new(player, project) }

  describe '#enabled?' do
    context 'with successfully sending' do
      let_it_be(:project) { create(:project, namespace: group) }

      before do
        create(:external_audit_event_destination, group: project.group)
      end

      context 'when player is a regular user' do
        it 'is enable' do
          expect(subject.enabled?).to be_truthy
        end
      end

      context 'when player is ::API::Support::GitAccessActor' do
        let_it_be(:user) { player }
        let_it_be(:key) { create(:key, user: user) }
        let_it_be(:git_access_actor) { ::API::Support::GitAccessActor.new(user: user, key: key) }

        subject { described_class.new(git_access_actor, project) }

        it 'is enable too' do
          expect(subject.enabled?).to be_truthy
        end
      end
    end

    context 'with disallowed scenarios' do
      context 'when feature flag is disabled' do
        it 'is disallowed' do
          stub_feature_flags(log_git_streaming_audit_events: false)

          expect(subject.enabled?).to be_falsey
        end
      end

      context 'when group is blank' do
        it 'is disable' do
          expect(subject.enabled?).to be_falsey
        end
      end

      context 'when group audit streaming event is not set' do
        let_it_be(:project) { create(:project, namespace: group) }

        it 'is disable' do
          expect(subject.enabled?).to be_falsey
        end
      end

      context 'when user is blank' do
        let_it_be(:player) { nil }

        it 'is disable' do
          expect(subject.enabled?).to be_falsey
        end
      end

      context 'when Gitlab.com? is true' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        it 'is disable' do
          expect(subject.enabled?).to be_falsey
        end
      end
    end
  end

  describe '#send_audit_event' do
    let(:msg) { 'valid_msg' }

    context 'with successfully sending' do
      let_it_be(:project) { create(:project, namespace: group) }

      before do
        allow(::Gitlab::Audit::Auditor).to receive(:audit)
      end

      context 'when player is a regular user' do
        it 'sends git audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
            name: 'repository_git_operation',
            stream_only: true,
            author: player,
            scope: project,
            target: project,
            message: msg
          )).once

          subject.send_audit_event(msg)
        end
      end

      context 'when player is ::API::Support::GitAccessActor' do
        let_it_be(:user) { player }
        let_it_be(:key) { create(:key, user: user) }
        let_it_be(:git_access_actor) { ::API::Support::GitAccessActor.new(user: user, key: key) }

        subject { described_class.new(git_access_actor, project) }

        it 'sends git audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
            name: 'repository_git_operation',
            stream_only: true,
            author: git_access_actor.deploy_key_or_user,
            scope: project,
            target: project,
            message: msg
          )).once

          subject.send_audit_event(msg)
        end
      end
    end

    context 'when user is blank' do
      let_it_be(:player) { nil }

      it 'does not send git audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        subject.send_audit_event(msg)
      end
    end

    context 'when project is blank' do
      let_it_be(:project) { nil }

      it 'does not send git audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        subject.send_audit_event(msg)
      end
    end
  end
end
