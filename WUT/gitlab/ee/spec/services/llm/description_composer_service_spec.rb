# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::DescriptionComposerService, :saas, feature_category: :code_review_workflow do
  let_it_be_with_refind(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) { create(:project, :public, group: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:options) { {} }

  subject(:service) { described_class.new(user, project, options) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(description_composer: true, ai_features: true, experimental_features: true)

    allow(user).to receive(:can?).with("read_project", project).and_call_original
    allow(user).to receive(:can?).with(:access_duo_features, merge_request.project).and_call_original
    allow(user).to receive(:can?).with(:admin_all_resources).and_call_original

    group.namespace_settings.update!(experiment_features_enabled: true)
  end

  describe '#execute' do
    before do
      allow(Llm::CompletionWorker).to receive(:perform_for)
    end

    context 'when the user is permitted to view the merge request' do
      before_all do
        group.add_developer(user)
      end

      before do
        allow(user)
          .to receive(:can?)
          .with(:access_description_composer, project)
          .and_return(true)
        allow(user).to receive(:allowed_to_use?).with(:description_composer).and_return(true)
      end

      it_behaves_like 'schedules completion worker' do
        let(:action_name) { :description_composer }
        let(:resource) { project }
      end
    end

    context 'when the user is not permitted to view the merge request' do
      before do
        allow(project).to receive(:member?).with(user).and_return(false)
      end

      it 'returns an error' do
        expect(service.execute).to be_error

        expect(Llm::CompletionWorker).not_to have_received(:perform_for)
      end
    end
  end

  describe '#valid?' do
    before_all do
      group.add_maintainer(user)
    end

    before do
      allow(user).to receive(:allowed_to_use?).with(:description_composer).and_return(true)
    end

    subject(:valid) { described_class.new(user, project, options).valid? }

    it 'returns true when user has access' do
      allow(user)
        .to receive(:can?)
        .with(:access_description_composer, project)
        .and_return(true)

      expect(valid).to be(true)
    end

    it 'returns false when user does not have access' do
      allow(user)
        .to receive(:can?)
        .with(:access_description_composer, project)
        .and_return(false)

      expect(valid).to be(false)
    end
  end
end
