# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UsersStatistics do
  let(:users_statistics) do
    build(:users_statistics, with_highest_role_minimal_access: 5, with_highest_role_guest_with_custom_role: 2)
  end

  describe '#billable' do
    it 'sums users statistics values excluding blocked users and bots' do
      expect(users_statistics.billable).to eq(81)
    end

    context 'when there is an ultimate license' do
      before do
        create_current_license(plan: License::ULTIMATE_PLAN)
      end

      it 'excludes blocked users, bots, guest users, users without a group or project and minimal access users' do
        expect(users_statistics.billable).to eq(50)
      end
    end
  end

  describe '#active' do
    it 'includes minimal access roles' do
      expect(users_statistics.active).to eq(83)
    end
  end

  describe '#non_billable' do
    it 'includes bots only' do
      expect(users_statistics.non_billable).to eq(2)
    end

    context 'when there is an ultimate license' do
      before do
        create_current_license(plan: License::ULTIMATE_PLAN)
      end

      it 'includes users without a group or project' do
        expect(users_statistics.non_billable).to eq(28)
      end
    end
  end

  describe '#non_billable_guests' do
    it 'sums only guests without an elevating custom role' do
      expect(users_statistics.non_billable_guests).to eq(3)
    end
  end

  describe '.create_current_stats!' do
    before do
      create(:user_highest_role, :minimal_access)

      allow(ApplicationRecord.connection).to receive(:transaction_open?).and_return(false)
    end

    it 'includes minimal access in current statistics values' do
      expect(described_class.create_current_stats!).to have_attributes(
        with_highest_role_minimal_access: 1
      )
    end

    it 'includes guests with custom role in current statistics values' do
      expect(described_class.create_current_stats!).to have_attributes(with_highest_role_guest_with_custom_role: 0)
    end
  end
end
