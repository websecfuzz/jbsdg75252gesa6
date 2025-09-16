# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CredentialsInventoryHelper, feature_category: :user_management do
  let(:filter) { nil }

  before do
    controller.params[:filter] = filter
  end

  describe '#credentials_inventory_feature_available?' do
    subject { credentials_inventory_feature_available? }

    context 'when credentials inventory feature is enabled' do
      before do
        stub_licensed_features(credentials_inventory: true)
      end

      it { is_expected.to be_truthy }
    end

    context 'when credentials inventory feature is disabled' do
      before do
        stub_licensed_features(credentials_inventory: false)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#show_resource_access_tokens?' do
    subject { show_resource_access_tokens? }

    context 'when filter value equals resource_access_tokens' do
      let(:filter) { 'resource_access_tokens' }

      it { is_expected.to be_truthy }
    end

    context 'when filter value is a value other than resource_access_tokens' do
      let(:filter) { 'other_access_tokens' }

      it { is_expected.to be_falsey }
    end

    context 'when filter value is nil' do
      let(:filter) { nil }

      it { is_expected.to be_falsey }
    end
  end

  describe '#show_ssh_keys?' do
    subject { show_ssh_keys? }

    context 'when filtering by ssh_keys' do
      let(:filter) { 'ssh_keys' }

      it { is_expected.to be_truthy }
    end

    context 'when filtering by a different, existent credential type' do
      let(:filter) { 'personal_access_tokens' }

      it { is_expected.to be_falsey }
    end

    context 'when filtering by a different, non-existent credential type' do
      let(:filter) { 'non-existent-filter' }

      it { is_expected.to be_falsey }
    end
  end

  describe '#show_gpg_keys?' do
    subject { show_gpg_keys? }

    context 'when filtering by gpg_keys' do
      let(:filter) { 'gpg_keys' }

      it { is_expected.to be true }
    end

    context 'when filtering by personal_access_tokens' do
      let(:filter) { 'personal_access_tokens' }

      it { is_expected.to be false }
    end
  end

  describe '#show_personal_access_tokens?' do
    subject { show_personal_access_tokens? }

    context 'when filtering by personal_access_tokens' do
      let(:filter) { 'personal_access_tokens' }

      it { is_expected.to be_truthy }
    end

    context 'when filtering by a different, existent credential type' do
      let(:filter) { 'ssh_keys' }

      it { is_expected.to be_falsey }
    end

    context 'when filtering by a different, non-existent credential type' do
      let(:filter) { 'non-existent-filter' }

      it { is_expected.to be_truthy }
    end
  end

  describe "#default_sort_order" do
    subject(:default_sort_order) { helper.default_sort_order }

    let(:sort_order) { 'expires_asc' }

    it { is_expected.to be(sort_order) }
  end

  describe "#default_filters" do
    subject(:default_filters) { helper.default_filters }

    let(:filters) do
      [
        :state, :revoked,
        :created_before, :created_after, :expires_before, :expires_after, :last_used_before, :last_used_after,
        :search, :sort, :owner_type
      ]
    end

    it { is_expected.to match_array(filters) }
  end
end
