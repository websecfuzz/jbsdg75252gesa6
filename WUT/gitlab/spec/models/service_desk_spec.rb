# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceDesk, feature_category: :service_desk do
  before do
    allow(Gitlab::Email::IncomingEmail).to receive_messages(
      enabled?: true,
      supports_wildcard?: true)
  end

  describe 'enabled?' do
    let_it_be(:parameter) { create(:project) }

    subject { described_class.enabled?(parameter) }

    it { is_expected.to be_truthy }

    context 'when parameter is group' do
      let(:parameter) { create(:group) }

      it { is_expected.to be_falsy }
    end

    context 'when parameter is namespace' do
      let(:parameter) { create(:namespace) }

      it { is_expected.to be_falsy }
    end

    context 'when service desk is not supported' do
      before do
        allow(described_class).to receive(:supported?).and_return(false)
      end

      it { is_expected.to be_falsy }
    end

    context 'when service desk is disabled for project' do
      before do
        parameter.update!(service_desk_enabled: false)
      end

      it { is_expected.to be_falsy }
    end
  end

  describe 'supported?' do
    subject { described_class.supported? }

    it { is_expected.to be_truthy }

    context 'when incoming emails are disabled' do
      before do
        allow(Gitlab::Email::IncomingEmail).to receive(:enabled?).and_return(false)
      end

      it { is_expected.to be_falsy }
    end

    context 'when email key is not supported' do
      before do
        allow(Gitlab::Email::IncomingEmail).to receive(:supports_wildcard?).and_return(false)
      end

      it { is_expected.to be_falsy }
    end
  end
end
