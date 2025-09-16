# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::NamespaceLimit::EmailNotificationService,
  feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers
  using RSpec::Parameterized::TableSyntax

  describe 'execute' do
    let(:mailer) { ::Namespaces::Storage::NamespaceLimitMailer }
    let(:action_mailer) { instance_double(ActionMailer::MessageDelivery) }

    before do
      enforce_namespace_storage_limit(group)
    end

    context 'in a saas environment', :saas do
      let_it_be(:group, refind: true) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:owner) { create(:user) }

      before_all do
        create(:namespace_root_storage_statistics, namespace: group)
        group.add_owner(owner)
      end

      where(:limit, :current_size, :usage_ratio, :last_notification_level, :expected_level) do
        100 | 100 | 1.0 | :storage_remaining | :exceeded
        100 | 200 | 2.0 | :storage_remaining | :exceeded
        100 | 100 | 1.0 | :caution           | :exceeded
        100 | 100 | 1.0 | :warning           | :exceeded
        100 | 100 | 1.0 | :danger            | :exceeded
      end

      with_them do
        it 'sends an out of storage notification when the namespace runs out of storage' do
          set_enforcement_limit(group, megabytes: limit)
          set_used_storage(group, megabytes: current_size)
          set_notification_level(last_notification_level)

          expect(mailer).to receive(:notify_out_of_storage).with(namespace: group, recipients: [owner.email],
            usage_values: {
              current_size: current_size.megabytes,
              limit: limit.megabytes,
              usage_ratio: usage_ratio
            })
            .and_return(action_mailer)
          expect(action_mailer).to receive(:deliver_later)

          described_class.execute(group)

          expect(group.root_storage_statistics.reload.notification_level.to_sym).to eq(expected_level)
        end
      end

      where(:limit, :current_size, :usage_ratio, :last_notification_level, :expected_level) do
        100  | 70   | 0.70 | :storage_remaining | :caution
        100  | 85   | 0.85 | :storage_remaining | :warning
        100  | 95   | 0.95 | :storage_remaining | :danger
        100  | 77   | 0.77 | :storage_remaining | :caution
        1000 | 971  | 0.971 | :storage_remaining | :danger
        100  | 85   | 0.85 | :caution           | :warning
        100  | 95   | 0.95 | :warning           | :danger
        100  | 99   | 0.99 | :exceeded          | :danger
        100  | 94   | 0.94 | :danger            | :warning
        100  | 84   | 0.84 | :warning           | :caution
        8192 | 6144 | 0.75 | :storage_remaining | :caution
        5120 | 3840 | 0.75 | :storage_remaining | :caution
      end

      with_them do
        it 'sends a storage limit notification when storage is running low' do
          set_enforcement_limit(group, megabytes: limit)
          set_used_storage(group, megabytes: current_size)
          set_notification_level(last_notification_level)

          expect(mailer).to receive(:notify_limit_warning).with(namespace: group, recipients: [owner.email],
            usage_values: {
              current_size: current_size.megabytes,
              limit: limit.megabytes,
              usage_ratio: usage_ratio
            })
            .and_return(action_mailer)
          expect(action_mailer).to receive(:deliver_later)

          described_class.execute(group)

          expect(group.root_storage_statistics.reload.notification_level.to_sym).to eq(expected_level)
        end
      end

      where(:limit, :current_size, :last_notification_level) do
        100  | 5   | :storage_remaining
        100  | 69  | :storage_remaining
        100  | 69  | :caution
        100  | 69  | :warning
        100  | 69  | :danger
        100  | 69  | :exceeded
        1000 | 699 | :exceeded
      end

      with_them do
        it 'does not send an email when there is sufficient storage remaining' do
          set_enforcement_limit(group, megabytes: limit)
          set_used_storage(group, megabytes: current_size)
          set_notification_level(last_notification_level)

          expect(mailer).not_to receive(:notify_out_of_storage)
          expect(mailer).not_to receive(:notify_limit_warning)

          described_class.execute(group)
        end
      end

      where(:limit, :current_size, :last_notification_level) do
        0    | 0   | :storage_remaining
        0    | 150 | :storage_remaining
        0    | 0   | :caution
        0    | 100 | :caution
        0    | 0   | :warning
        0    | 50  | :warning
        0    | 0   | :danger
        0    | 50  | :danger
        0    | 0   | :exceeded
        0    | 1   | :exceeded
      end

      with_them do
        it 'does not send an email when there is no storage limit' do
          set_enforcement_limit(group, megabytes: limit)
          set_used_storage(group, megabytes: current_size)
          set_notification_level(last_notification_level)

          expect(mailer).not_to receive(:notify_out_of_storage)
          expect(mailer).not_to receive(:notify_limit_warning)

          described_class.execute(group)

          expect(group.root_storage_statistics.reload.notification_level.to_sym).to eq(:storage_remaining)
        end
      end

      it 'sends an email to all group owners' do
        set_enforcement_limit(group, megabytes: 100)
        set_used_storage(group, megabytes: 200)
        owner2 = create(:user)
        group.add_owner(owner2)
        group.add_maintainer(create(:user))
        group.add_developer(create(:user))
        group.add_reporter(create(:user))
        group.add_guest(create(:user))
        owner_emails = [owner.email, owner2.email]

        expect(mailer).to receive(:notify_out_of_storage).with(namespace: group, recipients: match_array(owner_emails),
          usage_values: {
            current_size: 200.megabytes,
            limit: 100.megabytes,
            usage_ratio: 2.0
          })
          .and_return(action_mailer)
        expect(action_mailer).to receive(:deliver_later)

        described_class.execute(group)
      end

      it 'does not send an out of storage notification twice' do
        set_enforcement_limit(group, megabytes: 100)
        set_used_storage(group, megabytes: 200)
        set_notification_level(:exceeded)

        expect(mailer).not_to receive(:notify_out_of_storage)

        described_class.execute(group)
      end

      where(:limit, :current_size, :last_notification_level) do
        100  | 70  | :caution
        100  | 85  | :warning
        100  | 95  | :danger
      end

      with_them do
        it 'does not send a storage limit notification for the same threshold twice' do
          set_enforcement_limit(group, megabytes: limit)
          set_used_storage(group, megabytes: current_size)
          set_notification_level(last_notification_level)

          expect(mailer).not_to receive(:notify_limit_warning)

          described_class.execute(group)
        end
      end

      it 'does nothing if there is no root_storage_statistics' do
        group.root_storage_statistics.destroy!
        group.reload

        expect(mailer).not_to receive(:notify_out_of_storage)
        expect(mailer).not_to receive(:notify_limit_warning)

        described_class.execute(group)

        expect(group.reload.root_storage_statistics).to be_nil
      end

      context 'with a personal namespace' do
        let_it_be(:namespace) { create(:namespace_with_plan, plan: :ultimate_plan) }

        before_all do
          create(:namespace_root_storage_statistics, namespace: namespace)
        end

        before do
          enforce_namespace_storage_limit(namespace)
        end

        it 'sends a limit notification' do
          set_enforcement_limit(namespace, megabytes: 100)
          set_used_storage(namespace, megabytes: 85)
          owner = namespace.owner

          expect(mailer).to receive(:notify_limit_warning).with(namespace: namespace, recipients: [owner.email],
            usage_values: {
              current_size: 85.megabytes,
              limit: 100.megabytes,
              usage_ratio: 0.85
            })
            .and_return(action_mailer)
          expect(action_mailer).to receive(:deliver_later)

          described_class.execute(namespace)
        end

        it 'sends an out of storage notification' do
          set_enforcement_limit(namespace, megabytes: 100)
          set_used_storage(namespace, megabytes: 550)
          owner = namespace.owner

          expect(mailer).to receive(:notify_out_of_storage).with(namespace: namespace, recipients: [owner.email],
            usage_values: {
              current_size: 550.megabytes,
              limit: 100.megabytes,
              usage_ratio: 5.50
            })
            .and_return(action_mailer)
          expect(action_mailer).to receive(:deliver_later)

          described_class.execute(namespace)
        end
      end
    end

    context 'in a self-managed environment' do
      let_it_be(:group) { create(:group) }

      it 'does nothing' do
        create(:namespace_root_storage_statistics, namespace: group)
        owner = create(:user)
        group.add_owner(owner)
        set_used_storage(group, megabytes: 87)

        expect(mailer).not_to receive(:notify_out_of_storage)
        expect(mailer).not_to receive(:notify_limit_warning)

        described_class.execute(group)

        expect(group.root_storage_statistics.reload.notification_level).to eq('storage_remaining')
      end
    end
  end

  def set_notification_level(level)
    group.root_storage_statistics.update!(notification_level: level)
  end
end
