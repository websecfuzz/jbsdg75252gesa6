# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::MakeSecurityPolicyBotsPrivate, feature_category: :security_policy_management do
  describe '#perform' do
    let(:users) { table(:users) }

    let(:regular_user) do
      users.create!(user_type: 0, username: 'john_doe', email: 'johndoe@gitlab.com', projects_limit: 10)
    end

    let(:private_security_policy_bot) do
      users.create!(
        user_type: 10,
        private_profile: true,
        username: 'john_doe2',
        email: 'johndoe2@gitlab.com',
        projects_limit: 10
      )
    end

    let(:security_policy_bot) do
      users.create!(user_type: 10, username: 'john_doe3', email: 'johndoe3@gitlab.com', projects_limit: 10)
    end

    let(:migration_attrs) do
      {
        start_id: users.minimum(:id),
        end_id: users.maximum(:id),
        batch_table: :users,
        batch_column: :id,
        sub_batch_size: 100,
        pause_ms: 0,
        connection: ApplicationRecord.connection
      }
    end

    subject(:perform_migration) { described_class.new(**migration_attrs).perform }

    it 'updates the private_profile field for security policy bots' do
      expect { perform_migration }.to change { security_policy_bot.reload.private_profile }.from(false).to(true)

      expect(regular_user.private_profile).to eq(false)
      expect(private_security_policy_bot.private_profile).to eq(true)
    end
  end
end
