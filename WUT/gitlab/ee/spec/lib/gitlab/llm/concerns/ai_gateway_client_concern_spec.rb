# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Concerns::AiGatewayClientConcern, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { build(:user) }
  let_it_be(:group) { create(:group) } # Root namespace
  let_it_be(:subgroup) { create(:group, parent: group) } # Non-root namespace
  let_it_be(:tracking_context) { { source: 'test' } }

  let(:ai_gateway_client_double) { instance_double(Gitlab::Llm::AiGateway::Client) }

  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Concerns::AiGatewayClientConcern

      def initialize(user, tracking_context, root_namespace_override = nil)
        @user = user
        @tracking_context = tracking_context
        @root_namespace_override = root_namespace_override
      end

      def inputs
        { input: 'test_input' }
      end

      # Override root_namespace when specified
      def root_namespace
        @root_namespace_override
      end

      def execute
        perform_ai_gateway_request!(user: @user, tracking_context: @tracking_context)
      end

      # Test helpers to access private methods
      def test_namespace_feature_setting
        namespace_feature_setting
      end

      def test_selected_feature_setting
        selected_feature_setting
      end

      def test_base_url_from_feature_setting
        base_url_from_feature_setting
      end

      def test_prompt_version_or_default
        prompt_version_or_default
      end

      private

      def service_name
        'duo_chat'
      end

      def prompt_name
        'duo_chat'
      end
    end
  end

  before do
    stub_feature_flags(ai_model_switching: true)
    allow(::Gitlab::Llm::PromptVersions).to receive(:version_for_prompt).and_return('^1.0.0')
    allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_gateway_client_double)
  end

  describe '#perform_ai_gateway_request!' do
    subject(:execute_request) { dummy_class.new(user, tracking_context).execute }

    context 'when handling responses' do
      let(:response) { instance_double(HTTParty::Response, body: body, success?: true) }

      before do
        allow(ai_gateway_client_double).to receive(:complete_prompt).and_return(response)
      end

      context 'when the response is a string' do
        let(:body) { %("completion") }

        it 'returns the string' do
          expect(execute_request).to eq("completion")
        end
      end

      context 'when the response is a hash' do
        let(:body) { %({"content":"completion"}) }

        it 'returns the content of the response' do
          expect(execute_request).to eq("completion")
        end
      end
    end

    context 'with default configuration (no namespace, no feature settings)' do
      it 'executes the ai gateway request with default values' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'duo_chat',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          model_metadata: nil
        )

        execute_request
      end
    end

    context 'with self-hosted feature setting' do
      let!(:self_hosted_model) { create(:ai_self_hosted_model) }
      let!(:ai_feature_setting) do
        create(:ai_feature_setting,
          feature: 'duo_chat',
          provider: :self_hosted,
          self_hosted_model: self_hosted_model)
      end

      it 'uses self-hosted configuration' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ai_feature_setting.base_url,
          prompt_name: 'duo_chat',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          model_metadata: hash_including(:name)
        )

        execute_request
      end
    end

    context 'with vendored feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :vendored)
      end

      it 'uses vendored configuration' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'duo_chat',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          model_metadata: nil
        )

        execute_request
      end
    end

    context 'with namespace feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :self_hosted)
      end

      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'duo_chat',
          offered_model_ref: 'claude-3-7-sonnet-20250219')
      end

      subject(:execute_request) { dummy_class.new(user, tracking_context, group).execute }

      it 'prioritizes namespace feature setting over standard feature setting' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'duo_chat',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          model_metadata: hash_including(
            feature_setting: 'duo_chat',
            identifier: 'claude-3-7-sonnet-20250219',
            provider: 'gitlab'
          )
        )

        execute_request
      end
    end

    context 'with overridden prompt version' do
      let(:dummy_class_with_version) do
        Class.new(dummy_class) do
          def prompt_version
            '2.1.0'
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :vendored)
      end

      subject(:execute_request) { dummy_class_with_version.new(user, tracking_context).execute }

      it 'uses the overridden prompt version' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'duo_chat',
          inputs: { input: 'test_input' },
          prompt_version: '2.1.0',
          model_metadata: nil
        )

        execute_request
      end

      context 'when feature setting is self-hosted' do
        let!(:ai_feature_setting) do
          create(:ai_feature_setting, feature: 'duo_chat', provider: :self_hosted)
        end

        it 'uses default prompt version for self-hosted (ignores override)' do
          expect(ai_gateway_client_double).to receive(:complete_prompt).with(
            base_url: ai_feature_setting.base_url,
            prompt_name: 'duo_chat',
            inputs: { input: 'test_input' },
            prompt_version: '^1.0.0',
            model_metadata: hash_including(:name)
          )

          execute_request
        end
      end
    end
  end

  describe '#namespace_feature_setting' do
    subject(:instance) { dummy_class.new(user, tracking_context, group) }

    context 'when namespace feature setting exists' do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'duo_chat',
          offered_model_ref: 'claude-3-7-sonnet-20250219')
      end

      it 'returns the namespace feature setting' do
        result = instance.test_namespace_feature_setting
        expect(result).to eq(namespace_feature_setting)
        expect(result.feature).to eq('duo_chat')
        expect(result.offered_model_ref).to eq('claude-3-7-sonnet-20250219')
      end
    end

    context 'when no namespace feature setting exists' do
      it 'initializes a NamespaceFeatureSetting with duo_chat feature' do
        result = instance.test_namespace_feature_setting

        expect(result).to be_a(Ai::ModelSelection::NamespaceFeatureSetting)
        expect(result.feature).to eq("duo_chat")
      end
    end

    context 'when root_namespace is nil' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      it 'returns nil' do
        result = instance.test_namespace_feature_setting
        expect(result).to be_nil
      end
    end

    context 'when namespace is not a root namespace' do
      subject(:instance) { dummy_class.new(user, tracking_context, subgroup) }

      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'duo_chat',
          offered_model_ref: 'claude-3-7-sonnet-20250219')
      end

      it 'returns nil' do
        result = instance.test_namespace_feature_setting
        expect(result).to be_nil
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ai_model_switching: false)
      end

      let!(:namespace_feature_setting) do
        build(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'duo_chat',
          offered_model_ref: 'claude-3-7-sonnet-20250219')
      end

      it 'returns nil' do
        result = instance.test_namespace_feature_setting
        expect(result).to be_nil
      end
    end
  end

  describe '#selected_feature_setting' do
    let!(:ai_feature_setting) do
      create(:ai_feature_setting, feature: 'duo_chat', provider: :self_hosted)
    end

    context 'when namespace feature setting exists' do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'duo_chat',
          offered_model_ref: 'claude-3-7-sonnet-20250219')
      end

      subject(:instance) { dummy_class.new(user, tracking_context, group) }

      it 'returns namespace feature setting (priority)' do
        result = instance.test_selected_feature_setting
        expect(result).to eq(namespace_feature_setting)
        expect(result).to be_a(::Ai::ModelSelection::NamespaceFeatureSetting)
      end
    end

    context 'when only standard feature setting exists' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      it 'returns standard feature setting' do
        result = instance.test_selected_feature_setting
        expect(result).to eq(ai_feature_setting)
        expect(result).to be_a(::Ai::FeatureSetting)
      end
    end

    context 'when no feature settings exist' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      before do
        ai_feature_setting.destroy!
      end

      it 'returns nil' do
        result = instance.test_selected_feature_setting
        expect(result).to be_nil
      end
    end
  end

  describe '#base_url_from_feature_setting' do
    subject(:instance) { dummy_class.new(user, tracking_context, nil) }

    context 'with self-hosted feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :self_hosted)
      end

      it 'returns the base_url from feature setting' do
        result = instance.test_base_url_from_feature_setting
        expect(result).to eq(ai_feature_setting.base_url)
      end
    end

    context 'with vendored feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :vendored)
      end

      it 'returns default GitLab AiGateway URL' do
        result = instance.test_base_url_from_feature_setting
        expect(result).to eq(::Gitlab::AiGateway.url)
      end
    end

    context 'with namespace feature setting' do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'duo_chat',
          offered_model_ref: 'claude-3-7-sonnet-20250219')
      end

      subject(:instance) { dummy_class.new(user, tracking_context, group) }

      it 'returns default GitLab AiGateway URL (namespace settings have no base_url)' do
        result = instance.test_base_url_from_feature_setting
        expect(result).to eq(::Gitlab::AiGateway.url)
      end
    end

    context 'when no feature setting exists' do
      it 'returns default GitLab AiGateway URL' do
        result = instance.test_base_url_from_feature_setting
        expect(result).to eq(::Gitlab::AiGateway.url)
      end
    end
  end

  describe '#prompt_version_or_default' do
    subject(:instance) { dummy_class.new(user, tracking_context, nil) }

    context 'with vendored feature setting and custom prompt version' do
      let(:dummy_class_with_version) do
        Class.new(dummy_class) do
          def prompt_version
            '2.1.0'
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :vendored)
      end

      subject(:instance) { dummy_class_with_version.new(user, tracking_context, nil) }

      it 'returns the custom prompt version' do
        result = instance.test_prompt_version_or_default
        expect(result).to eq('2.1.0')
      end
    end

    context 'with self-hosted feature setting and custom prompt version' do
      let(:dummy_class_with_version) do
        Class.new(dummy_class) do
          def prompt_version
            '2.1.0'
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :self_hosted)
      end

      subject(:instance) { dummy_class_with_version.new(user, tracking_context, nil) }

      it 'returns the default version (ignores custom for self-hosted)' do
        result = instance.test_prompt_version_or_default
        expect(result).to eq('^1.0.0')
      end
    end

    context 'with no custom prompt version' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'duo_chat', provider: :vendored)
      end

      it 'returns the default version' do
        result = instance.test_prompt_version_or_default
        expect(result).to eq('^1.0.0')
      end
    end
  end

  describe 'method implementations' do
    let(:incomplete_class) do
      Class.new do
        include Gitlab::Llm::Concerns::AiGatewayClientConcern

        def initialize(user, tracking_context)
          @user = user
          @tracking_context = tracking_context
        end

        def execute
          perform_ai_gateway_request!(user: @user, tracking_context: @tracking_context)
        end
      end
    end

    [:service_name, :prompt_name, :inputs].each do |method|
      it "raises NotImplementedError when #{method} is not implemented" do
        expect { incomplete_class.new(user, tracking_context).execute }.to raise_error(NotImplementedError)
      end
    end

    context 'when all required methods are implemented' do
      let(:complete_class) do
        Class.new(incomplete_class) do
          def inputs
            { input: 'test' }
          end

          private

          def service_name
            'test_service'
          end

          def prompt_name
            'test_prompt'
          end
        end
      end

      it 'does not raise NotImplementedError' do
        expect(ai_gateway_client_double).to receive(:complete_prompt)

        expect { complete_class.new(user, tracking_context).execute }.not_to raise_error
      end
    end
  end

  describe 'default method implementations' do
    subject(:instance) { dummy_class.new(user, tracking_context) }

    describe '#root_namespace' do
      it 'returns nil by default' do
        expect(instance.root_namespace).to be_nil
      end
    end
  end

  describe 'strong memoization' do
    subject(:instance) { dummy_class.new(user, tracking_context, group) }

    let!(:namespace_feature_setting) do
      create(:ai_namespace_feature_setting,
        namespace: group,
        feature: 'duo_chat',
        offered_model_ref: 'claude-3-7-sonnet-20250219')
    end

    it 'memoizes namespace_feature_setting' do
      expect(::Ai::ModelSelection::NamespaceFeatureSetting)
        .to receive(:find_or_initialize_by_feature).once.and_call_original

      # Call multiple times
      instance.test_namespace_feature_setting
      instance.test_namespace_feature_setting
      instance.test_selected_feature_setting
    end

    it 'memoizes selected_feature_setting' do
      # selected_feature_setting calls namespace_feature_setting internally
      expect(::Ai::ModelSelection::NamespaceFeatureSetting)
        .to receive(:find_or_initialize_by_feature).once.and_call_original

      # Call multiple times
      instance.test_selected_feature_setting
      instance.test_selected_feature_setting
    end
  end
end
