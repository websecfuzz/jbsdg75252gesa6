# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Administration::VerifySelfHostedSetup, :gitlab_duo, :silence_stdout, feature_category: :"self-hosted_models" do
  include RakeHelpers

  let_it_be(:user) { create(:user, :admin, id: 1, username: 'root') }
  let_it_be(:user1) { create(:user, :admin, id: 2) }
  let(:rake_task) { instance_double(Rake::Task, invoke: true) }
  let(:ai_gateway_url) { 'http://ai-gateway.local' }
  let(:use_self_signed_token) { "1" }
  let(:license_provides_code_suggestions) { true }
  let(:can_user_access_code_suggestions) { true }
  let(:status_code) { 200 }
  let(:health_response_body) { '{"status": "healthy"}' }
  let(:http_response) do
    instance_double(HTTParty::Response, body: health_response_body, code: status_code, headers: {})
  end

  let(:username) { user1.username }
  let(:task) { described_class.new(username) }

  subject(:verify_setup) { task.execute }

  before do
    allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)
    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
    allow(Ai::Setting).to receive(:instance).and_return(Ai::Setting.new(ai_gateway_url: ai_gateway_url))
    stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', use_self_signed_token)
    stub_licensed_features(code_suggestions: license_provides_code_suggestions)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :access_code_suggestions)
                                        .and_return(can_user_access_code_suggestions)
    allow(Ability).to receive(:allowed?).with(user1, :access_code_suggestions)
                                        .and_return(can_user_access_code_suggestions)

    # Mock AI Gateway health check
    allow(Gitlab::HTTP).to receive(:get).with("#{ai_gateway_url}/monitoring/healthz",
      headers: { "accept" => "application/json" }, allow_local_requests: true, timeout: 10)
                                        .and_return(http_response)
  end

  describe '#execute' do
    context 'when everything is set properly' do
      it 'completes without error' do
        expect { verify_setup }.not_to raise_error
      end

      it 'fetches the correct user' do
        expect(User).to receive(:find_by_username!).with(username).and_call_original
        verify_setup
      end

      it 'collects system information' do
        verify_setup
        expect(task.diagnostics[:system]).to include(
          gitlab_version: Gitlab::VERSION,
          user: user1.username,
          user_id: user1.id
        )
      end

      context 'when not passing user' do
        let(:username) { nil }

        it 'uses root user' do
          expect(User).to receive(:find_by_username!).with('root').and_call_original
          verify_setup
        end
      end
    end

    context 'when ai_gateway_url is not set' do
      let(:ai_gateway_url) { nil }

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Set 'Ai::Setting\.instance\.ai_gateway_url'/)
        expect(task.diagnostics[:ai_gateway_url][:status]).to eq('ERROR')
      end
    end

    context 'when ai_gateway_url has invalid format' do
      let(:ai_gateway_url) { 'invalid-url' }

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Invalid AI Gateway URL format/)
        expect(task.diagnostics[:ai_gateway_url][:status]).to eq('ERROR')
      end
    end

    context 'when user does not have :code_suggestions permission' do
      let(:can_user_access_code_suggestions) { false }

      context 'and license provides code suggestions' do
        it 'raises error with diagnostic info' do
          expect { verify_setup }.to raise_error(
            RuntimeError,
            /License is correct, but user does not have access to code suggestions/
          )
          expect(task.diagnostics[:license]).to include(
            feature_available: true,
            user_has_access: false,
            error: "License valid but user lacks access"
          )
        end
      end

      context 'and license does not provide code suggestions' do
        let(:license_provides_code_suggestions) { false }

        it 'raises error with diagnostic info' do
          expect { verify_setup }.to raise_error(
            RuntimeError,
            /License does not provide access to code suggestions, verify your license/
          )
          expect(task.diagnostics[:license]).to include(
            feature_available: false,
            user_has_access: false,
            error: "License does not provide code suggestions feature"
          )
        end
      end
    end

    context 'when connection to ai_gateway fails' do
      before do
        allow(Gitlab::HTTP).to receive(:get).with("#{ai_gateway_url}/monitoring/healthz",
          headers: { "accept" => "application/json" }, allow_local_requests: true, timeout: 10)
                                            .and_raise(Errno::ECONNREFUSED)
      end

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Cannot access AI Gateway/)
        expect(task.diagnostics[:ai_gateway_health]).to include(
          status: 'ERROR',
          error: 'Errno::ECONNREFUSED'
        )
      end
    end

    context 'when response from ai_gateway is not 200' do
      let(:status_code) { 500 }

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Cannot access AI Gateway/)
        expect(task.diagnostics[:ai_gateway_health]).to include(
          status: 'ERROR',
          http_code: 500
        )
      end
    end
  end

  describe '#verify_model_endpoints!' do
    context 'when no models are configured' do
      it 'records warning in diagnostics' do
        task.send(:verify_model_endpoints!)
        expect(task.diagnostics[:self_hosted_models]).to include(
          status: 'WARNING',
          count: 0,
          error: 'No self-hosted models configured'
        )
      end
    end

    context 'when models are configured' do
      let_it_be(:model1) { create(:ai_self_hosted_model, name: 'Code Model', model: :codestral) }
      let_it_be(:model2) { create(:ai_self_hosted_model, name: 'Chat Model', model: :mistral) }

      it 'records model information in diagnostics' do
        task.send(:verify_model_endpoints!)
        expect(task.diagnostics[:self_hosted_models]).to include(
          status: 'OK',
          count: 2
        )

        model_data = task.diagnostics[:self_hosted_models][:models]
        expect(model_data).to include(
          hash_including(
            name: 'Code Model',
            model_type: 'codestral',
            release_state: 'GA',
            ga: true
          )
        )
      end
    end
  end

  describe '#verify_feature_settings!' do
    context 'when no feature settings are configured' do
      let_it_be(:model) { create(:ai_self_hosted_model) }

      it 'records warning in diagnostics' do
        task.send(:verify_feature_settings!)
        expect(task.diagnostics[:feature_settings]).to include(
          status: 'WARNING',
          total_features: 0,
          warning: 'No feature settings configured for any models'
        )
      end
    end

    context 'when feature settings are configured' do
      let!(:model1) { create(:ai_self_hosted_model, name: 'Code Model') }
      let!(:model2) { create(:ai_self_hosted_model, name: 'Chat Model') }
      let!(:feature_setting1) { create(:ai_feature_setting, feature: :code_generations, self_hosted_model: model1) }
      let!(:feature_setting2) do
        create(:ai_feature_setting, feature: :duo_chat_troubleshoot_job, self_hosted_model: model1)
      end

      let!(:feature_setting3) do
        create(:ai_feature_setting, feature: :generate_commit_message, self_hosted_model: model2)
      end

      it 'records feature settings in diagnostics' do
        task.send(:verify_feature_settings!)
        expect(task.diagnostics[:feature_settings][:status]).to eq('OK')
        expect(task.diagnostics[:feature_settings][:total_features]).to eq(3)
        expect(task.diagnostics[:feature_settings][:features]).to be_an(Array)
        expect(task.diagnostics[:feature_settings][:features].length).to eq(3)

        model_names = task.diagnostics[:feature_settings][:features].pluck(:model_name)
        expect(model_names).to include('Code Model', 'Chat Model')
      end

      it 'shows code model has 2 features assigned' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /Code Model: 2 feature\(s\) assigned/
        ).to_stdout
      end

      it 'shows chat model has 1 feature assigned' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /Chat Model: 1 feature\(s\) assigned/
        ).to_stdout
      end

      it 'shows correct feature count summary' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /3 feature settings configured/
        ).to_stdout
      end
    end

    context 'when models exist but no features are assigned' do
      let_it_be(:model1) { create(:ai_self_hosted_model, name: 'Unused Model') }
      let_it_be(:model2) { create(:ai_self_hosted_model, name: 'Another Unused Model') }

      it 'shows warning about unassigned models' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /No feature settings configured ⚠/
        ).to_stdout
      end

      it 'includes helpful message about model availability' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /Models may not be available for any GitLab Duo features/
        ).to_stdout
      end
    end
  end

  describe '#test_request_flow!' do
    context 'when no models are configured' do
      it 'skips testing and records in diagnostics' do
        task.send(:test_request_flow!)
        expect(task.diagnostics[:request_flow]).to include(
          status: 'SKIPPED',
          reason: 'No models configured to test'
        )
      end
    end

    context 'when models are configured' do
      let_it_be(:model1) { create(:ai_self_hosted_model, name: 'Test Model', endpoint: 'http://model1.local') }
      let_it_be(:model2) { create(:ai_self_hosted_model, name: 'Test Model 2', endpoint: 'http://model2.local') }

      let(:model_response) { instance_double(HTTParty::Response, body: '{"data": []}', code: 200, headers: {}) }

      before do
        allow(Gitlab::HTTP).to receive(:get).with(
          "http://model1.local/v1/models",
          hash_including(headers: hash_including('accept' => 'application/json'))
        ).and_return(model_response)

        allow(Gitlab::HTTP).to receive(:get).with(
          "http://model2.local/v1/models",
          hash_including(headers: hash_including('accept' => 'application/json'))
        ).and_return(model_response)
      end

      it 'tests model endpoints and records results' do
        task.send(:test_request_flow!)
        expect(task.diagnostics[:request_flow]).to include(
          status: 'OK',
          models_tested: 2
        )

        model_tests = task.diagnostics[:request_flow][:model_tests]
        expect(model_tests).to all(include(status: 'OK'))
      end

      context 'when model endpoint fails' do
        before do
          allow(Gitlab::HTTP).to receive(:get).with(
            "http://model1.local/v1/models",
            hash_including(headers: hash_including('accept' => 'application/json'))
          ).and_raise(Errno::ECONNREFUSED)
        end

        it 'records the failure in diagnostics' do
          task.send(:test_request_flow!)

          failed_test = task.diagnostics[:request_flow][:model_tests].find { |t| t[:model_name] == 'Test Model' }
          expect(failed_test).to include(
            status: 'ERROR',
            error: 'Errno::ECONNREFUSED'
          )
        end
      end
    end
  end

  describe '#test_model_endpoint' do
    let(:model) { create(:ai_self_hosted_model, name: 'Test Model', endpoint: 'http://test.local', api_token: 'secret') }
    let(:model_response) { instance_double(HTTParty::Response, body: '{"data": []}', code: 200, headers: {}) }

    it 'includes authorization header when api_token is present' do
      expect(Gitlab::HTTP).to receive(:get).with(
        "http://test.local/v1/models",
        hash_including(
          headers: hash_including('authorization' => 'Bearer secret')
        )
      ).and_return(model_response)

      result = task.send(:test_model_endpoint, model)
      expect(result[:has_auth]).to be true
      expect(result[:status]).to eq('OK')
    end

    context 'when model has no api_token' do
      let(:model) { create(:ai_self_hosted_model, name: 'Test Model', endpoint: 'http://test.local', api_token: nil) }

      it 'does not include authorization header' do
        expect(Gitlab::HTTP).to receive(:get).with(
          "http://test.local/v1/models",
          hash_including(
            headers: hash_not_including('authorization')
          )
        ).and_return(model_response)

        result = task.send(:test_model_endpoint, model)
        expect(result[:has_auth]).to be false
      end
    end
  end

  describe '#sanitize_headers' do
    it 'removes sensitive headers' do
      headers = {
        'content-type' => 'application/json',
        'authorization' => 'Bearer secret-token',
        'x-api-key' => 'api-key',
        'cookie' => 'session=abc123'
      }

      result = task.send(:sanitize_headers, headers)

      expect(result).to include('content-type' => 'application/json')
      expect(result).not_to include('authorization', 'x-api-key', 'cookie')
    end

    it 'truncates long header values' do
      long_value = 'x' * 200
      headers = { 'custom-header' => long_value }

      result = task.send(:sanitize_headers, headers)
      expect(result['custom-header'].length).to eq(100)
    end

    it 'handles nil input' do
      expect(task.send(:sanitize_headers, nil)).to eq({})
    end
  end

  describe '#output_diagnostics' do
    it 'outputs JSON formatted diagnostics' do
      task.instance_variable_set(:@diagnostics, { test: 'data' })

      expect(Gitlab::Json).to receive(:pretty_generate).with({ test: 'data' })
      expect { task.send(:output_diagnostics) }.to output(/NOTE: Review the above output/).to_stdout
    end
  end

  describe 'diagnostics structure' do
    it 'includes all expected diagnostic sections when successful' do
      verify_setup

      expect(task.diagnostics).to include(
        :system,
        :ai_gateway_url,
        :license,
        :ai_gateway_health,
        :self_hosted_models,
        :feature_settings,
        :request_flow
      )
    end

    it 'includes system information with required fields' do
      verify_setup

      system_info = task.diagnostics[:system]
      expect(system_info).to include(
        :gitlab_version,
        :gitlab_revision,
        :rails_env,
        :timestamp,
        :user,
        :user_id,
        :instance_url
      )
    end
  end
end
