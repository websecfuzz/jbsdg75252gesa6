# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::ProjectJobTokenScope, feature_category: :secrets_management do
  let_it_be(:project) do
    create(:project,
      :public,
      ci_inbound_job_token_scope_enabled: true,
      ci_outbound_job_token_scope_enabled: true
    )
  end

  let_it_be(:current_user) { create(:user) }

  let(:options) { { current_user: current_user } }
  let(:entity) { described_class.new(project, options) }

  describe "#as_json" do
    subject { entity.as_json }

    context 'when instance_level_token_scope_enabled is false' do
      before do
        Gitlab::CurrentSettings.update!(enforce_ci_inbound_job_token_scope_enabled: false)
      end

      it 'inbound_enabled and outbound_enabled default to true' do
        expect(subject).to eq(
          inbound_enabled: true,
          outbound_enabled: true
        )
      end

      it 'inbound_enabled can be changed at the project level' do
        project.update!(ci_inbound_job_token_scope_enabled: false)

        expect(subject).to eq(
          inbound_enabled: false,
          outbound_enabled: true
        )
      end
    end

    context 'when instance_level_token_scope_enabled is true' do
      before do
        Gitlab::CurrentSettings.update!(enforce_ci_inbound_job_token_scope_enabled: true)
      end

      it 'inbound_enabled and outbound_enabled default to true' do
        expect(subject).to eq(
          inbound_enabled: true,
          outbound_enabled: true
        )
      end

      it 'inbound_enabled can not be changed at the project level' do
        project.update!(ci_inbound_job_token_scope_enabled: false)

        expect(subject).to eq(
          inbound_enabled: true,
          outbound_enabled: true
        )
      end
    end
  end
end
