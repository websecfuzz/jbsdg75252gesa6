# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::CodeSuggestions, feature_category: :code_suggestions do
  include WorkhorseHelpers
  include GitlabSubscriptions::SaasSetAssignmentHelpers

  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:unauthorized_user) { build(:user) }
  let_it_be(:tokens) do
    {
      api: create(:personal_access_token, scopes: %w[api], user: authorized_user),
      read_api: create(:personal_access_token, scopes: %w[read_api], user: authorized_user),
      ai_features: create(:personal_access_token, scopes: %w[ai_features], user: authorized_user),
      unauthorized_user: create(:personal_access_token, scopes: %w[api], user: unauthorized_user)
    }
  end

  let(:enabled_by_namespace_ids) { [] }
  let(:enablement_type) { '' }
  let(:current_user) { nil }
  let(:headers) { {} }
  let(:access_code_suggestions) { true }
  let(:is_saas) { true }
  let(:global_instance_id) { 'instance-ABC' }
  let(:global_user_id) { 'user-ABC' }
  let(:gitlab_realm) { 'saas' }
  let(:service_name) { :code_suggestions }
  let(:service) { instance_double('::CloudConnector::SelfSigned::AvailableServiceData') }
  let_it_be(:token) { 'generated-jwt' }

  before do
    allow(Gitlab).to receive(:com?).and_return(is_saas)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(authorized_user, :access_code_suggestions, :global)
                                        .and_return(access_code_suggestions)
    allow(Ability).to receive(:allowed?).with(unauthorized_user, :access_code_suggestions, :global)
                                        .and_return(false)

    allow(Gitlab::InternalEvents).to receive(:track_event)
    allow(Gitlab::Tracking::AiTracking).to receive(:track_event)

    allow(Gitlab::GlobalAnonymousId).to receive(:user_id).and_return(global_user_id)
    allow(Gitlab::GlobalAnonymousId).to receive(:instance_id).and_return(global_instance_id)

    allow(::CloudConnector::AvailableServices).to receive(:find_by_name).with(service_name).and_return(service)
    allow(service).to receive_messages(access_token: token, name: service_name, add_on_names: ['code_suggestions'])

    purchases = class_double(GitlabSubscriptions::AddOnPurchase)
    mock_purchase = instance_double(GitlabSubscriptions::AddOnPurchase, normalized_add_on_name: 'duo_pro')
    allow(GitlabSubscriptions::AddOnPurchase).to(
      receive_message_chain(:for_active_add_ons, :assigned_to_user).and_return(purchases)
    )
    allow(purchases).to receive_messages(any?: true, uniq_namespace_ids: enabled_by_namespace_ids, last: mock_purchase)

    stub_feature_flags(incident_fail_over_completion_provider: false)
    stub_feature_flags(use_claude_code_completion: false)
    stub_feature_flags(code_completion_opt_out_fireworks: false)
  end

  shared_examples 'a response' do |case_name|
    it "returns #{case_name} response", :freeze_time, :aggregate_failures do
      post_api

      expect(response).to have_gitlab_http_status(result)

      expect(json_response).to include(**response_body)
    end

    it "records Snowplow events" do
      post_api

      if case_name == 'successful'
        expect_snowplow_event(
          category: described_class.name,
          action: :authenticate,
          user: current_user,
          label: 'code_suggestions'
        )
      else
        expect_no_snowplow_event
      end
    end
  end

  shared_examples 'an unauthorized response' do
    include_examples 'a response', 'unauthorized' do
      let(:result) { :unauthorized }
      let(:response_body) do
        { "message" => "401 Unauthorized" }
      end
    end
  end

  shared_examples 'an endpoint authenticated with token' do |success_http_status = :created|
    let(:current_user) { nil }
    let(:access_token) { tokens[:api] }

    before do
      stub_feature_flags(ai_duo_code_suggestions_switch: true)
      headers["Authorization"] = "Bearer #{access_token.token}"

      post_api
    end

    context 'when using token with :api scope' do
      it { expect(response).to have_gitlab_http_status(success_http_status) }
    end

    context 'when using token with :ai_features scope' do
      let(:access_token) { tokens[:ai_features] }

      it { expect(response).to have_gitlab_http_status(success_http_status) }
    end

    context 'when using token with :read_api scope' do
      let(:access_token) { tokens[:read_api] }

      it { expect(response).to have_gitlab_http_status(:forbidden) }
    end

    context 'when using token with :read_api scope but for an unauthorized user' do
      let(:access_token) { tokens[:unauthorized_user] }

      it 'checks access_code_suggestions ability for user and return 401 unauthorized' do
        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(response.headers['X-GitLab-Error-Origin']).to eq('monolith')
      end
    end
  end

  shared_examples_for 'rate limited and tracked endpoint' do |rate_limit_key:, event_name:|
    it_behaves_like 'rate limited endpoint', rate_limit_key: rate_limit_key

    it 'tracks rate limit exceeded event' do
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

      request

      expect(Gitlab::InternalEvents)
        .to have_received(:track_event)
        .with(event_name, user: current_user)
    end
  end

  shared_examples 'code suggestions feature disabled' do
    let(:access_token) { tokens[:api] }

    before do
      stub_feature_flags(ai_duo_code_suggestions_switch: false)
      headers["Authorization"] = "Bearer #{access_token.token}"

      post_api
    end

    it 'returns 404' do
      post_api

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'POST /code_suggestions/completions' do
    let(:access_code_suggestions) { true }

    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def add(x, y):
          return x + y

        def sub(x, y):
          return x - y

        def multiple(x, y):
          return x * y

        def divide(x, y):
          return x / y

        def is_even(n: int) ->
      CONTENT_ABOVE_CURSOR
    end

    let(:file_name) { 'test.py' }
    let(:additional_params) { {} }
    let(:body) do
      {
        project_path: "gitlab-org/gitlab-shell",
        project_id: 33191677, # not removed given we still might get it but we will not use it
        current_file: {
          file_name: file_name,
          content_above_cursor: content_above_cursor,
          content_below_cursor: ''
        },
        stream: false,
        model_name: 'codestral-2501',
        model_provider: 'fireworks_ai',
        **additional_params
      }
    end

    let(:v3_saas_code_generation_prompt_components) do
      {
        "prompt_components" => [
          {
            "type" => "code_editor_generation",
            "payload" => {
              "file_name" => "test.py",
              "content_above_cursor" => "def is_even(n: int) ->\n# A " \
                "function that outputs the first 20 fibonacci numbers\n",
              "content_below_cursor" => "",
              "language_identifier" => "Python",
              "stream" => false,
              "prompt_enhancer" => {
                "examples_array" => [
                  {
                    "example" => "class Project:\n  def __init__(self, name, public):\n    " \
                      "self.name = name\n    self.visibility = 'PUBLIC' if public\n\n    " \
                      "# is this project public?\n{{cursor}}\n\n    # print name of this project",
                    "response" => "<new_code>def is_public(self):\n  return self.visibility == 'PUBLIC'",
                    "trigger_type" => "comment"
                  },
                  {
                    "example" => "def get_user(session):\n  # get the current user's " \
                      "name from the session data\n{{cursor}}\n\n# is the current user an admin",
                    "response" => "<new_code>username = None\nif 'username' in session:\n  " \
                      "username = session['username']\nreturn username",
                    "trigger_type" => "comment"
                  }
                ],
                'trimmed_content_above_cursor' => "def is_even(n: int) ->\n# A " \
                  "function that outputs the first 20 fibonacci numbers\n",
                'trimmed_content_below_cursor' => '',
                'related_files' => [],
                'related_snippets' => [],
                'libraries' => [],
                'user_instruction' => 'Generate the best possible code based on instructions.'
              },
              'prompt_id' => 'code_suggestions/generations',
              'prompt_version' => '2.0.0'
            }
          }
        ]
      }
    end

    subject(:post_api) do
      post api('/code_suggestions/completions', current_user), headers: headers, params: body.to_json
    end

    before do
      allow(Gitlab::ApplicationRateLimiter).to receive(:threshold).and_return(0)
    end

    shared_examples 'code completions endpoint' do
      context 'when feature is disabled' do
        include_examples 'code suggestions feature disabled'
      end

      context 'when user is not logged in' do
        let(:current_user) { nil }

        include_examples 'an unauthorized response'
      end

      context 'when user does not have access to code suggestions' do
        let(:access_code_suggestions) { false }

        include_examples 'an unauthorized response'
      end

      context 'when user is logged in' do
        let(:current_user) { authorized_user }

        it_behaves_like 'rate limited and tracked endpoint',
          { rate_limit_key: :code_suggestions_api_endpoint,
            event_name: 'code_suggestions_rate_limit_exceeded' } do
          def request
            post api('/code_suggestions/completions', current_user), headers: headers, params: body.to_json
          end
        end

        it 'delegates downstream service call to Workhorse with correct auth token' do
          post_api

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to eq("".to_json)
          command, params = workhorse_send_data
          expect(command).to eq('send-url')
          expect(params).to include(
            'URL' => "#{::Gitlab::AiGateway.url}/v2/code/completions",
            'AllowRedirects' => false,
            'Body' => body.merge(prompt_version: 1).to_json,
            'Method' => 'POST',
            'ResponseHeaderTimeout' => '55s'
          )
          expect(params['Header']).to include(
            'X-Gitlab-Authentication-Type' => ['oidc'],
            'x-gitlab-instance-id' => [global_instance_id],
            'x-gitlab-global-user-id' => [global_user_id],
            'x-gitlab-host-name' => [Gitlab.config.gitlab.host],
            'x-gitlab-realm' => [gitlab_realm],
            'Authorization' => ["Bearer #{token}"],
            'x-gitlab-feature-enabled-by-namespace-ids' => [""],
            'Content-Type' => ['application/json'],
            'User-Agent' => ['Super Awesome Browser 43.144.12'],
            "x-gitlab-enabled-feature-flags" => ["expanded_ai_logging"]
          )
        end

        context 'when expanded_ai_logging is disabled' do
          before do
            # this will set Feature.enabled?(expanded_ai_logging, unauthorized_user) to true
            # and Feature.enabled?(expanded_ai_logging, authorized_user) to false
            # post_api is calling the api with authorized_user
            stub_feature_flags(expanded_ai_logging: [unauthorized_user])
          end

          it 'delegates downstream service call to Workhorse with correct auth token' do
            post_api
            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to eq("".to_json)
            _, params = workhorse_send_data
            expect(params['Header']).to include("x-gitlab-enabled-feature-flags" => [""])
          end
        end

        context 'when incident_fail_over_completion_provider is enabled' do
          before do
            stub_feature_flags(incident_fail_over_completion_provider: true)
          end

          let(:current_user) { authorized_user }

          it 'delegates downstream service call to Workhorse with correct auth token' do
            post_api
            expected_body = body.merge(
              'model_provider' => 'anthropic',
              'model_name' => 'claude-3-5-sonnet-20240620',
              'prompt_version' => 3,
              'prompt' => [
                {
                  "role" => "system",
                  "content" => "You are a code completion tool that performs Fill-in-the-middle. Your task is to " \
                    "complete the Python code between the given prefix and suffix inside the file 'test.py'.\n" \
                    "Your task is to provide valid code without any additional explanations, comments, or feedback." \
                    "\n\nImportant:\n- You MUST NOT output any additional human text or explanation.\n- You MUST " \
                    "output code exclusively.\n- The suggested code MUST work by simply concatenating to the " \
                    "provided code.\n- You MUST not include any sort of markdown markup.\n- You MUST NOT repeat or " \
                    "modify any part of the prefix or suffix.\n- You MUST only provide the missing code that fits " \
                    "between them.\n\nIf you are not able to complete code based on the given instructions, " \
                    "return an empty result."
                },
                {
                  "role" => "user",
                  "content" => "<SUFFIX>\ndef add(x, y):\n  return x + y\n\ndef sub(x, y):\n  return x - " \
                    "y\n\ndef multiple(x, y):\n  return x * y\n\ndef divide(x, y):\n  return x / y\n\n" \
                    "def is_even(n: int) ->\n\n</SUFFIX>\n<PREFIX>\n\n</PREFIX>"
                }
              ]
            )

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to eq("".to_json)
            command, params = workhorse_send_data
            expect(command).to eq('send-url')
            expect(params).to include(
              'URL' => "#{::Gitlab::AiGateway.url}/v2/code/completions",
              'AllowRedirects' => false,
              'Body' => expected_body.to_json,
              'Method' => 'POST',
              'ResponseHeaderTimeout' => '55s'
            )
            expect(params['Header']).to include(
              'X-Gitlab-Authentication-Type' => ['oidc'],
              'x-gitlab-instance-id' => [global_instance_id],
              'x-gitlab-global-user-id' => [global_user_id],
              'x-gitlab-host-name' => [Gitlab.config.gitlab.host],
              'x-gitlab-realm' => [gitlab_realm],
              'Authorization' => ["Bearer #{token}"],
              'x-gitlab-feature-enabled-by-namespace-ids' => [""],
              'Content-Type' => ['application/json'],
              'User-Agent' => ['Super Awesome Browser 43.144.12'],
              "x-gitlab-enabled-feature-flags" => ["expanded_ai_logging"]
            )
          end
        end

        context 'when using Fireworks/Codestral' do
          let(:fireworks_codestral_model_details) do
            {
              'model_provider' => 'fireworks_ai',
              'model_name' => 'codestral-2501'
            }
          end

          it 'sends a code completion request with the fireworks/codestral model details' do
            post_api

            _command, params = workhorse_send_data
            code_completion_params = Gitlab::Json.parse(params['Body'])
            expect(code_completion_params).to include(**fireworks_codestral_model_details)
          end
        end

        context 'with telemetry headers' do
          let(:headers) do
            {
              'X-Gitlab-Authentication-Type' => 'oidc',
              'X-Gitlab-Oidc-Token' => token,
              'Content-Type' => 'application/json',
              'X-GitLab-NO-Ignore' => 'ignoreme',
              'X-Gitlab-Language-Server-Version' => '4.21.0',
              'User-Agent' => 'Super Cool Browser 14.5.2'
            }
          end

          it 'proxies appropriate headers to code suggestions service' do
            post_api

            _, params = workhorse_send_data
            expect(params['Header']).to include({
              'X-Gitlab-Authentication-Type' => ['oidc'],
              'Authorization' => ["Bearer #{token}"],
              'x-gitlab-feature-enabled-by-namespace-ids' => [""],
              'Content-Type' => ['application/json'],
              'x-gitlab-instance-id' => [global_instance_id],
              'x-gitlab-global-user-id' => [global_user_id],
              'x-gitlab-host-name' => [Gitlab.config.gitlab.host],
              'x-gitlab-realm' => [gitlab_realm],
              'X-Gitlab-Language-Server-Version' => ['4.21.0'],
              'User-Agent' => ['Super Cool Browser 14.5.2'],
              "x-gitlab-enabled-feature-flags" => ["expanded_ai_logging"]
            })
          end
        end

        context 'when passing intent parameter' do
          context 'with completion intent' do
            let(:additional_params) { { intent: 'completion' } }

            it 'passes completion intent into TaskFactory.new' do
              expect(::CodeSuggestions::TaskFactory).to receive(:new)
                .with(
                  current_user,
                  client: kind_of(CodeSuggestions::Client),
                  params: hash_including(intent: 'completion'),
                  unsafe_passthrough_params: kind_of(Hash)
                ).and_call_original

              post_api
            end
          end

          context 'with generation intent' do
            let(:additional_params) { { intent: 'generation' } }

            it 'passes generation intent into TaskFactory.new' do
              expect(::CodeSuggestions::TaskFactory).to receive(:new)
                .with(
                  current_user,
                  client: kind_of(CodeSuggestions::Client),
                  params: hash_including(intent: 'generation'),
                  unsafe_passthrough_params: kind_of(Hash)
                ).and_call_original

              post_api
            end
          end
        end

        context 'when passing stream parameter' do
          let(:additional_params) { { stream: true } }

          it 'passes stream into TaskFactory.new' do
            expect(::CodeSuggestions::TaskFactory).to receive(:new)
              .with(
                current_user,
                client: kind_of(CodeSuggestions::Client),
                params: hash_including(stream: true),
                unsafe_passthrough_params: kind_of(Hash)
              ).and_call_original

            post_api
          end
        end

        context 'when passing generation_type parameter' do
          let(:additional_params) { { generation_type: :small_file } }

          it 'passes generation_type into TaskFactory.new' do
            expect(::CodeSuggestions::TaskFactory).to receive(:new)
              .with(
                current_user,
                client: kind_of(CodeSuggestions::Client),
                params: hash_including(generation_type: 'small_file'),
                unsafe_passthrough_params: kind_of(Hash)
              ).and_call_original

            post_api
          end
        end

        context 'when passing project_path parameter' do
          let(:additional_params) { { project_path: 'group/test-project' } }

          it 'passes project_path into TaskFactory.new' do
            expect(::CodeSuggestions::TaskFactory).to receive(:new)
              .with(
                current_user,
                client: kind_of(CodeSuggestions::Client),
                params: hash_including(project_path: 'group/test-project'),
                unsafe_passthrough_params: kind_of(Hash)
              ).and_call_original

            post_api
          end
        end

        context 'when passing user_instruction parameter' do
          let(:additional_params) { { user_instruction: 'Generate tests for this file' } }

          it 'passes user_instruction into TaskFactory.new' do
            expect(::CodeSuggestions::TaskFactory).to receive(:new)
              .with(
                current_user,
                client: kind_of(CodeSuggestions::Client),
                params: hash_including(user_instruction: 'Generate tests for this file'),
                unsafe_passthrough_params: kind_of(Hash)
              ).and_call_original

            post_api
          end
        end

        context 'when passing context parameter' do
          let(:additional_params) do
            {
              context: [
                {
                  type: 'file',
                  name: 'main.go',
                  content: 'package main\nfunc main()\n{\n}\n'
                },
                {
                  type: 'snippet',
                  name: 'fullName',
                  content: 'func fullName(first, last string) {\nfmt.Println(first, last)\n}'
                }
              ]
            }
          end

          it 'passes context into TaskFactory.new' do
            expect(::CodeSuggestions::TaskFactory).to receive(:new)
              .with(
                current_user,
                client: kind_of(CodeSuggestions::Client),
                params: hash_including(context: additional_params[:context]),
                unsafe_passthrough_params: kind_of(Hash)
              ).and_call_original

            post_api
          end

          context 'when context is blank' do
            let(:additional_params) { { context: [] } }

            it 'responds with bad request' do
              post_api

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body).to eq({ error: "context is empty" }.to_json)
            end
          end

          context 'when context missing a content' do
            let(:additional_params) do
              {
                context: [
                  {
                    type: 'file',
                    name: 'main.go'
                  }
                ]
              }
            end

            it 'responds with bad request' do
              post_api

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body)
                .to eq({ error: "context[0][content] is missing, context[0][content] is empty" }.to_json)
            end
          end

          context 'when context missing a type' do
            let(:additional_params) do
              {
                context: [
                  {
                    name: 'main.go',
                    content: 'package main\nfunc main()\n{\n}\n'
                  }
                ]
              }
            end

            it 'responds with bad request' do
              post_api

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body).to eq({ error: "context[0][type] is missing" }.to_json)
            end
          end

          context 'when context missing a name' do
            let(:additional_params) do
              {
                context: [
                  {
                    type: 'file',
                    content: 'package main\nfunc main()\n{\n}\n'
                  }
                ]
              }
            end

            it 'responds with bad request' do
              post_api

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body).to eq({ error: "context[0][name] is missing, context[0][name] is empty" }.to_json)
            end
          end

          context 'when context type is incorrect' do
            let(:additional_params) do
              {
                context: [
                  {
                    type: 'unknown',
                    name: 'main.go',
                    content: 'package main\nfunc main()\n{\n}\n'
                  }
                ]
              }
            end

            it 'responds with bad request' do
              post_api

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body).to eq({ error: "context[0][type] does not have a valid value" }.to_json)
            end
          end
        end
      end
    end

    context 'when the instance is Gitlab.org_or_com' do
      let(:is_saas) { true }
      let_it_be(:token) { 'generated-jwt' }

      let(:headers) do
        {
          'X-Gitlab-Authentication-Type' => 'oidc',
          'X-Gitlab-Oidc-Token' => token,
          'Content-Type' => 'application/json',
          'User-Agent' => 'Super Awesome Browser 43.144.12'
        }
      end

      context 'when user belongs to a namespace with an active code suggestions purchase' do
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

        let(:current_user) { authorized_user }

        before_all do
          add_on_purchase.namespace.add_reporter(authorized_user)
        end

        context 'when the user is assigned to the add-on' do
          before_all do
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: authorized_user,
              add_on_purchase: add_on_purchase
            )
          end

          context 'when the task is code generation' do
            let(:current_user) { authorized_user }
            let(:content_above_cursor) do
              <<~CONTENT_ABOVE_CURSOR
                def is_even(n: int) ->
                # A function that outputs the first 20 fibonacci numbers
              CONTENT_ABOVE_CURSOR
            end

            let(:system_prompt) do
              <<~PROMPT.chomp
                You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Python code inside the
                file 'test.py' based on instructions from the user.

                Here are a few examples of successfully generated code:

                <examples>

                  <example>
                  H: <existing_code>
                       class Project:
                  def __init__(self, name, public):
                    self.name = name
                    self.visibility = 'PUBLIC' if public

                    # is this project public?
                {{cursor}}

                    # print name of this project
                     </existing_code>

                  A: <new_code>def is_public(self):
                  return self.visibility == 'PUBLIC'</new_code>
                  </example>

                  <example>
                  H: <existing_code>
                       def get_user(session):
                  # get the current user's name from the session data
                {{cursor}}

                # is the current user an admin
                     </existing_code>

                  A: <new_code>username = None
                if 'username' in session:
                  username = session['username']
                return username</new_code>
                  </example>

                </examples>
                <existing_code>
                #{content_above_cursor}{{cursor}}
                </existing_code>
                The existing code is provided in <existing_code></existing_code> tags.

                The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
                In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
                likely new code to generate at the cursor position to fulfill the instructions.

                The comment directly before the {{cursor}} position is the instruction,
                all other comments are not instructions.

                When generating the new code, please ensure the following:
                1. It is valid Python code.
                2. It matches the existing code's variable, parameter and function names.
                3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
                4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
                5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
                6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

                Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
                If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
              PROMPT
            end

            let(:prompt) do
              [
                { role: :system, content: system_prompt },
                { role: :user, content: 'Generate the best possible code based on instructions.' },
                { role: :assistant, content: '<new_code>' }
              ]
            end

            it 'sends requests to the code generation v3 endpoint' do
              expected_body = body.merge(v3_saas_code_generation_prompt_components)
              expect(Gitlab::Workhorse)
                .to receive(:send_url)
                .with(
                  "#{::Gitlab::AiGateway.url}/v3/code/completions",
                  hash_including(body: expected_body.to_json)
                )

              post_api
            end

            it 'includes additional headers for SaaS', :freeze_time do
              group = create(:group)
              group.add_developer(authorized_user)

              post_api

              _, params = workhorse_send_data
              expect(params['Header']).to include(
                'X-Gitlab-Saas-Namespace-Ids' => [''],
                'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' => [add_on_purchase.namespace.id.to_s],
                'X-Gitlab-Rails-Send-Start' => [Time.now.to_f.to_s]
              )
            end

            context 'when body is too big' do
              before do
                stub_const("#{described_class}::MAX_BODY_SIZE", 10)
              end

              it 'returns an error' do
                post_api

                expect(response).to have_gitlab_http_status(:payload_too_large)
              end
            end

            context 'when a required parameter is invalid' do
              let(:file_name) { 'x' * 256 }

              it 'returns an error' do
                post_api

                expect(response).to have_gitlab_http_status(:bad_request)
              end
            end
          end

          it_behaves_like 'code completions endpoint'

          it_behaves_like 'an endpoint authenticated with token', :ok

          describe 'Fireworks/Codestral opt out by ops FF' do
            before do
              stub_feature_flags(code_completion_opt_out_fireworks: user_duo_group)
            end

            let(:user_duo_group) do
              Group.by_id(current_user.duo_available_namespace_ids).first
            end

            it 'does send code completion model details for vertex codestral' do
              post_api

              _command, params = workhorse_send_data
              code_completion_params = Gitlab::Json.parse(params['Body'])
              expect(code_completion_params['model_provider']).to eq('vertex-ai')
              expect(code_completion_params['model_name']).to eq('codestral-2501')
            end
          end
        end
      end
    end

    context 'when the instance is Gitlab self-managed' do
      let(:is_saas) { false }
      let(:gitlab_realm) { 'self-managed' }

      let_it_be(:token) { 'stored-token' }
      let_it_be(:service_access_token) { create(:service_access_token, :active, token: token) }

      let(:headers) do
        {
          'X-Gitlab-Authentication-Type' => 'oidc',
          'Content-Type' => 'application/json',
          'User-Agent' => 'Super Awesome Browser 43.144.12'
        }
      end

      context 'when user is authorized' do
        let(:current_user) { authorized_user }

        it 'does not include additional headers, which are for SaaS only', :freeze_time do
          post_api

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to eq("".to_json)
          _, params = workhorse_send_data
          expect(params['Header']).not_to have_key('X-Gitlab-Saas-Namespace-Ids')
          expect(params['Header']).to include('X-Gitlab-Rails-Send-Start' => [Time.now.to_f.to_s])
        end

        context 'when code suggestions feature is self hosted' do
          let(:service_name) { :self_hosted_models }

          before do
            stub_licensed_features(ai_features: true)
          end

          context 'when the feature is set to `disabled` state' do
            let_it_be(:feature_setting) do
              create(:ai_feature_setting, feature: :code_completions, provider: :disabled)
            end

            it 'is unauthorized' do
              post_api

              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(response.headers['X-GitLab-Error-Origin']).to eq('monolith')
            end
          end
        end

        context 'when Amazon Q is connected' do
          let(:service_name) { :amazon_q_integration }

          before do
            stub_licensed_features(amazon_q: true)
            allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
          end

          it 'is authorized' do
            post_api

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      it_behaves_like 'code completions endpoint'
      it_behaves_like 'an endpoint authenticated with token', :ok

      context 'when there is no active code suggestions token' do
        before do
          create(:service_access_token, :expired, token: token)
        end

        include_examples 'a response', 'unauthorized' do
          let(:result) { :unauthorized }
          let(:response_body) do
            { "message" => "401 Unauthorized" }
          end
        end
      end
    end
  end

  describe 'POST /code_suggestions/direct_access', :freeze_time do
    subject(:post_api) { post api('/code_suggestions/direct_access', current_user), params: params }

    let(:params) { {} }

    context 'when unauthorized' do
      let(:current_user) { unauthorized_user }

      it_behaves_like 'an unauthorized response'
    end

    context 'when authorized' do
      shared_examples_for 'user request with code suggestions allowed' do
        context 'when token creation succeeds' do
          before do
            allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
              allow(client).to receive(:direct_access_token)
                .and_return({ status: :success, token: token, expires_at: expected_expiration })
            end

            ::Ai::Setting.instance.update!(enabled_instance_verbose_ai_logs: false)
          end

          let(:expected_response) do
            {
              'base_url' => ::Gitlab::AiGateway.url,
              'expires_at' => expected_expiration,
              'token' => token,
              'headers' => expected_headers,
              'model_details' => { 'model_name' => 'codestral-2501', 'model_provider' => 'fireworks_ai' }
            }
          end

          it 'returns direct access details', :freeze_time do
            post_api

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response).to match(expected_response)
          end

          context 'when using Fireworks/Codestral' do
            it 'includes the fireworks/codestral model metadata in the direct access details' do
              post_api

              expect(json_response['model_details']).to eq({
                'model_provider' => 'fireworks_ai',
                'model_name' => 'codestral-2501'
              })
            end
          end

          context 'when code completions is self-hosted' do
            it 'does not include the model metadata in the direct access details' do
              create(:ai_feature_setting, provider: :self_hosted, feature: :code_completions)

              post_api

              expect(json_response['model_details']).to be_nil
            end

            context 'when code completions is disabled' do
              it 'returns unauthorized' do
                create(:ai_feature_setting, provider: :disabled, feature: :code_completions)

                post_api

                expect(response).to have_gitlab_http_status(:unauthorized)
              end
            end
          end
        end

        context 'when token creation fails' do
          before do
            allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
              allow(client).to receive(:direct_access_token).and_return({ status: :error, message: 'an error' })
            end
          end

          it 'returns an error' do
            post_api

            expect(response).to have_gitlab_http_status(:service_unavailable)
          end
        end
      end

      let(:current_user) { authorized_user }
      let(:expected_expiration) { Time.now.to_i + 3600 }
      let(:enablement_type) { 'duo_pro' }

      let(:base_headers) do
        {
          'x-gitlab-global-user-id' => global_user_id,
          'x-gitlab-instance-id' => global_instance_id,
          'x-gitlab-host-name' => Gitlab.config.gitlab.host,
          'x-gitlab-realm' => gitlab_realm,
          'x-gitlab-version' => Gitlab.version_info.to_s,
          'X-Gitlab-Authentication-Type' => 'oidc',
          'x-gitlab-feature-enabled-by-namespace-ids' => enabled_by_namespace_ids.join(','),
          "x-gitlab-feature-enablement-type" => enablement_type,
          'x-gitlab-enabled-feature-flags' => '',
          "x-gitlab-enabled-instance-verbose-ai-logs" => 'false',
          "X-Gitlab-Model-Prompt-Cache-Enabled" => "true"
        }
      end

      let(:headers) { {} }
      let(:expected_headers) { base_headers.merge(headers) }

      let(:token) { 'user token' }

      it_behaves_like 'rate limited and tracked endpoint',
        { rate_limit_key: :code_suggestions_direct_access,
          event_name: 'code_suggestions_direct_access_rate_limit_exceeded' } do
        before do
          allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
            allow(client).to receive(:direct_access_token)
              .and_return({ status: :success, token: token, expires_at: expected_expiration })
          end
        end

        def request
          post api('/code_suggestions/direct_access', current_user)
        end
      end

      context 'when user belongs to a namespace with an active code suggestions purchase' do
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }
        let_it_be(:enabled_by_namespace_ids) { [add_on_purchase.namespace_id] }

        let(:headers) do
          {
            'X-Gitlab-Saas-Namespace-Ids' => '',
            'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' => add_on_purchase.namespace_id.to_s
          }
        end

        before_all do
          add_on_purchase.namespace.add_reporter(authorized_user)
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: authorized_user,
            add_on_purchase: add_on_purchase
          )
        end

        it_behaves_like 'user request with code suggestions allowed'

        describe 'Fireworks/Codestral opt out by ops FF' do
          before do
            allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
              allow(client).to receive(:direct_access_token)
                .and_return({ status: :success, token: token, expires_at: expected_expiration })
            end

            stub_feature_flags(code_completion_opt_out_fireworks: user_duo_group)
          end

          let(:user_duo_group) do
            Group.by_id(current_user.duo_available_namespace_ids).first
          end

          it 'does not include the model metadata in the direct access details' do
            post_api

            expect(json_response['model_details']).to eq({
              'model_provider' => 'vertex-ai',
              'model_name' => 'codestral-2501'
            })
          end
        end

        context 'when use_claude_code_completion FF is true' do
          let(:user_duo_group) do
            Group.by_id(current_user.duo_available_namespace_ids).first
          end

          before do
            stub_feature_flags(use_claude_code_completion: user_duo_group)
          end

          include_examples 'a response', 'unauthorized' do
            let(:result) { :forbidden }
            let(:response_body) do
              { 'message' => '403 Forbidden - Direct connections are disabled' }
            end
          end
        end

        context 'when user has a namespace with a pinned model' do
          before do
            group = Group.by_id(current_user.duo_available_namespace_ids).first

            create(:ai_namespace_feature_setting, feature: :code_completions, namespace: group)
          end

          include_examples 'a response', 'unauthorized' do
            let(:result) { :forbidden }
            let(:response_body) do
              { 'message' => '403 Forbidden - Direct connections are disabled' }
            end
          end
        end

        # First, define the shared example outside the contexts
        shared_examples 'model prompt cache enabled setting' do |setting_level, cache_value|
          let(:cache) { cache_value }

          it "returns direct access details with model_prompt_cache_enabled from #{setting_level}" do
            post_api
            expect(json_response["headers"]["X-Gitlab-Model-Prompt-Cache-Enabled"]).to eq(cache)
          end
        end

        describe 'model_prompt_cache_enabled' do
          # by default: enabled_application_setting.model_prompt_cache_enabled==true
          let_it_be(:enabled_application_setting) { create(:application_setting) }
          let_it_be(:current_user) { authorized_user }
          let(:top_level_namespace) { create(:group) }
          let(:group) { create(:group, parent: top_level_namespace) }
          let(:project) { create(:project, group: group) }
          let(:params) { { 'project_path' => project.full_path } }

          before do
            allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
              allow(client).to receive(:direct_access_token)
                                 .and_return({ status: :success, token: token, expires_at: expected_expiration })
            end
            project.add_developer(current_user)
          end

          context 'when model_prompt_cache_enabled is disabled on project setting' do
            let(:project_setting) { create(:project_setting, model_prompt_cache_enabled: false) }
            let(:project) { create(:project, group: group, project_setting: project_setting) }

            include_examples 'model prompt cache enabled setting', 'project setting', "false"
          end

          context 'when model_prompt_cache_enabled is disabled on namespace setting' do
            let(:top_level_namespace) { create(:group, :model_prompt_cache_disabled) }

            include_examples 'model prompt cache enabled setting', 'top level namespace setting', "false"
          end

          context 'when model_prompt_cache_enabled is enabled on application setting' do
            let(:top_level_namespace) { create(:group) }

            include_examples 'model prompt cache enabled setting', 'application setting', "true"
          end
        end
      end

      context 'when not SaaS' do
        let_it_be(:active_token) { create(:service_access_token, :active) }
        let(:is_saas) { false }
        let(:expected_expiration) { active_token.expires_at.to_i }
        let(:gitlab_realm) { 'self-managed' }

        it_behaves_like 'user request with code suggestions allowed'
      end

      context 'when disabled_direct_code_suggestions setting is true' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:disabled_direct_code_suggestions).and_return(true)
        end

        include_examples 'a response', 'unauthorized' do
          let(:result) { :forbidden }
          let(:response_body) do
            { 'message' => '403 Forbidden - Direct connections are disabled' }
          end
        end
      end

      context 'when incident_fail_over_completion_provider setting is true' do
        before do
          stub_feature_flags(incident_fail_over_completion_provider: true)
        end

        include_examples 'a response', 'unauthorized' do
          let(:result) { :forbidden }
          let(:response_body) do
            { 'message' => '403 Forbidden - Direct connections are disabled' }
          end
        end
      end

      context 'when amazon q is connected' do
        before do
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        end

        include_examples 'a response', 'unauthorized' do
          let(:result) { :forbidden }
          let(:response_body) do
            { 'message' => '403 Forbidden - Direct connections are disabled' }
          end
        end
      end
    end
  end

  context 'when checking if project has duo features enabled' do
    let_it_be(:enabled_project) { create(:project, :in_group, :private, :with_duo_features_enabled) }
    let_it_be(:disabled_project) { create(:project, :in_group, :with_duo_features_disabled) }

    let(:current_user) { authorized_user }

    subject { post api("/code_suggestions/enabled", current_user), params: { project_path: project_path } }

    context 'when authorized to view project' do
      before_all do
        enabled_project.add_maintainer(authorized_user)
        disabled_project.add_maintainer(authorized_user)
      end

      context 'when enabled' do
        let(:project_path) { enabled_project.full_path }

        it { is_expected.to eq(200) }
      end

      context 'when disabled' do
        let(:project_path) { disabled_project.full_path }

        it { is_expected.to eq(403) }
      end
    end

    context 'when not logged in' do
      let(:current_user) { nil }
      let(:project_path) { enabled_project.full_path }

      it { is_expected.to eq(401) }
    end

    context 'when logged in but not authorized to view project' do
      let(:project_path) { enabled_project.full_path }

      it { is_expected.to eq(404) }
    end

    context 'when project for project path does not exist' do
      let(:project_path) { 'not_a_real_project' }

      it { is_expected.to eq(404) }
    end
  end
end
