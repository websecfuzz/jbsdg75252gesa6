# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelinePolicy, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create_default(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  subject(:policy) { described_class.new(user, pipeline) }

  shared_context 'with rights' do |licensed: true, user_authorized: true, chat_authorized: true, read_build: true|
    before do
      stub_licensed_features(troubleshoot_job: licensed)
      allow(user).to receive(:allowed_to_use?).and_return(user_authorized)
      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:resource,
        :allowed?).and_return(chat_authorized)
      allow(policy).to receive(:can?).with(:read_build, project).and_return(read_build)
    end
  end

  shared_examples 'troubleshoot access check' do |expectation|
    it "#{expectation ? 'allows' : 'disallows'} troubleshooting" do
      expectation ? expect_allowed(:troubleshoot_job_with_ai) : expect_disallowed(:troubleshoot_job_with_ai)
    end
  end

  describe 'pipeline troubleshoot access' do
    context 'with full access' do
      include_context 'with rights'
      it_behaves_like 'troubleshoot access check', true
    end

    context 'without chat authorizer access' do
      include_context 'with rights', chat_authorized: false
      it_behaves_like 'troubleshoot access check', false
    end

    context 'without user authorization' do
      include_context 'with rights', user_authorized: false
      it_behaves_like 'troubleshoot access check', false
    end

    context 'without license' do
      include_context 'with rights', licensed: false
      it_behaves_like 'troubleshoot access check', false
    end

    context 'without read build' do
      include_context 'with rights', read_build: false
      it_behaves_like 'troubleshoot access check', false
    end
  end

  describe 'admin custom roles', :enable_admin_mode do
    context 'when user does not have read_pipeline ability (no access to the project)' do
      let_it_be(:project) { create_default(:project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      it { is_expected.to be_disallowed(:read_pipeline_metadata) }

      context 'when user can read_admin_cicd' do
        before do
          stub_licensed_features(custom_roles: true)
          create(:admin_member_role, :read_admin_cicd, user: user)
        end

        it { is_expected.to be_disallowed(:read_pipeline) }
        it { is_expected.to be_allowed(:read_pipeline_metadata) }
      end
    end
  end
end
