# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::EnablementCheckService, type: :service, feature_category: :duo_workflow do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  describe '#execute' do
    subject(:result) { described_class.new(project: project, current_user: user).execute }

    it { is_expected.to be_nil }

    context "when user has developer access" do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.not_to be_nil }

      context 'when duo_workflow licensed feature is available' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
          # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
          allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
          # rubocop:enable RSpec/AnyInstanceOf
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be_truthy
          expect(success_checks(result[:checks]))
            .to match_array([:developer_access, :duo_features_enabled, :feature_flag, :feature_available])
        end
      end

      context 'when duo_workflow feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow: false)
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be_falsey
          expect(success_checks(result[:checks])).to match_array([:developer_access, :duo_features_enabled])
        end
      end

      context 'when project has duo features disabled' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be_falsey
          expect(success_checks(result[:checks])).to match_array([:developer_access, :feature_flag])
        end
      end
    end

    context 'when user has guest access' do
      before_all do
        project.add_guest(user)
      end

      it "returns status and checks" do
        expect(result[:enabled]).to be_falsey
        expect(success_checks(result[:checks])).to match_array([:duo_features_enabled, :feature_flag])
      end
    end

    def success_checks(checks)
      checks.filter { |check| check[:value] }.pluck(:name)
    end
  end
end
