# frozen_string_literal: true

module QA
  RSpec.describe 'Create', product_group: :code_creation do
    include Support::API

    # These tests require several feature flags, user settings, and instance configurations.
    # See https://docs.gitlab.com/ee/development/ai_features/code_suggestions/#code-suggestions-development-setup
    # https://docs.gitlab.com/ee/api/code_suggestions.html
    describe 'Code Suggestions' do
      let(:expected_v3_response_data) do
        {
          metadata: a_hash_including(
            model: a_hash_including(engine: anything, name: anything, lang: anything),
            timestamp: anything
          ),
          choices: [anything]
        }
      end

      let(:expected_v2_response_data) do
        {
          id: 'id',
          model: a_hash_including(engine: anything, name: anything, lang: anything,
            tokens_consumption_metadata: anything),
          object: 'text_completion',
          created: anything,
          choices: [anything]
        }
      end

      let(:token) { Runtime::User::Store.user_api_client.personal_access_token }

      let(:direct_access) { Resource::CodeSuggestions::DirectAccess.fetch_direct_connection_details(token) }

      let(:context) do
        [
          { type: 'file', name: 'hello.rb', content: "def hello\n  puts \"hi\"\nend\n" },
          { type: 'snippet', name: 'log', content: "Log.debug(message)" }
        ]
      end

      shared_examples 'indirect code generation' do |testcase|
        it 'returns a suggestion', testcase: testcase do
          response = get_indirect_suggestion(prompt_data)
          expect_status_code(200, response)
          verify_suggestion(response, expected_v3_response_data)
        end
      end

      shared_examples 'indirect code completion' do |testcase|
        it 'returns a suggestion', testcase: testcase do
          response = get_indirect_suggestion(prompt_data)

          expect_status_code(200, response)
          verify_suggestion(response, expected_v2_response_data)
        end
      end

      shared_examples 'code suggestions API using streaming' do |testcase|
        it 'streams a suggestion', testcase: testcase do
          response = get_indirect_suggestion(prompt_data)

          expect_status_code(200, response)

          expect(response.headers[:content_type].include?('event-stream')).to be_truthy, 'Expected an event stream'
          expect(response).not_to be_empty, 'Expected the first line of a stream'
        end
      end

      shared_examples 'unauthorized' do |testcase|
        it 'returns no suggestion', testcase: testcase do
          response = get_indirect_suggestion(prompt_data)

          expect_status_code(401, response)
        end
      end

      context 'when code completion' do
        # using a longer block of code to avoid SMALL_FILE_TRIGGER so we get code completion
        let(:content_above_cursor) do
          <<-RUBY_PROMPT.chomp
            class Vehicle
              attr_accessor :make, :model, :year

              def drive
                puts "Driving the \#{make} \#{model} from \#{year}."
              end

              def reverse
                puts "Reversing the \#{make} \#{model} from \#{year}."
              end

              def honk_horn(sound)
                puts "Beep beep the \#{make} \#{model} from \#{year} is honking its horn. \#{sound}"
              end
            end

            vehicle = Vehicle.new
            vehicle.
          RUBY_PROMPT
        end

        let(:prompt_data) do
          {
            prompt_version: 1,
            telemetry: [],
            current_file: {
              file_name: '/test.rb',
              content_above_cursor: content_above_cursor,
              content_below_cursor: "\n\n\n\n\n",
              language_identifier: 'ruby'
            },
            intent: 'completion'
          }.compact
        end

        context 'on SaaS', :smoke, :external_ai_provider,
          only: { pipeline: %w[staging-canary staging canary production] } do
          it_behaves_like 'indirect code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/436992'
          context 'with context' do
            let(:prompt_data) { super().merge(context: context) }

            it_behaves_like 'indirect code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/500005'
          end
        end

        context 'on Self-managed', :orchestrated do
          let(:token) { Runtime::User::Store.admin_api_client.personal_access_token }

          context 'with a valid license' do
            context 'with a Duo Enterprise add-on' do
              context 'when seat is assigned', :ai_gateway do
                it_behaves_like 'indirect code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/436993'

                context 'with context' do
                  let(:prompt_data) { super().merge(context: context) }

                  it_behaves_like 'indirect code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/500006'
                end
              end
            end
          end
        end
      end

      context 'when code generation is requested' do
        let(:stream) { false }
        let(:prompt_data) do
          {
            prompt_version: 1,
            project_path: 'gitlab-org/gitlab',
            project_id: 278964,
            current_file: {
              file_name: '/http.rb',
              content_above_cursor: '# generate a http server',
              content_below_cursor: '',
              language_identifier: 'ruby'
            },
            stream: stream,
            intent: 'generation'
          }.compact
        end

        context 'on SaaS', :smoke, :external_ai_provider,
          only: { pipeline: %w[staging-canary staging canary production] } do
          it_behaves_like 'indirect code generation', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/420973'
        end

        context 'on Self-managed', :orchestrated do
          let(:token) { Runtime::User::Store.admin_api_client.personal_access_token }

          context 'with a valid license' do
            context 'with a Duo Enterprise add-on' do
              context 'when seat is assigned', :ai_gateway do
                it_behaves_like 'indirect code generation', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/462967'
              end

              context 'when seat is not assigned', :ai_gateway_no_seat_assigned, quarantine: {
                issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/547883',
                type: :flaky
              } do
                # Code suggestions is included with Duo Core
                include_examples 'indirect code generation', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/451487'
              end
            end

            context 'with no Duo Enterprise add-on', :ai_gateway_no_add_on, quarantine: {
              issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/547883',
              type: :flaky
            } do
              # Code suggestions is included with Duo Core
              include_examples 'indirect code generation', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/452448'
            end
          end

          context 'with no license', :ai_gateway_no_license do
            include_examples 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/446249'
          end
        end

        context 'when streaming' do
          let(:stream) { true }

          context 'on SaaS', :smoke, :external_ai_provider,
            only: { pipeline: %w[staging-canary staging canary production] } do
            include_examples 'code suggestions API using streaming', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/436994'
          end

          context 'on Self-managed', :orchestrated do
            let(:token) { Runtime::User::Store.admin_api_client.personal_access_token }

            context 'with a valid license' do
              context 'with a Duo Enterprise add-on' do
                context 'when seat is assigned', :ai_gateway do
                  include_examples 'code suggestions API using streaming', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/462968'
                end
              end
            end
          end
        end
      end

      context 'when direct access', feature_flag: { name: :incident_fail_over_completion_provider } do
        shared_examples 'direct code completion' do |testcase|
          it 'returns a completion directly from AI gateway', testcase: testcase do
            failed_over = Runtime::Feature.enabled?("incident_fail_over_completion_provider")

            if failed_over
              expect { get_direct_suggestion(prompt_data) }.to raise_error(RuntimeError, "Unexpected status code 403")
            else
              response = get_direct_suggestion(prompt_data)
              expect_status_code(200, response)
              verify_suggestion(response, expected_v2_response_data)
            end
          end
        end

        shared_examples 'direct code generation' do |testcase|
          it 'refuses a code generation request directly from AI gateway', testcase: testcase do
            failed_over = Runtime::Feature.enabled?("incident_fail_over_completion_provider")

            if failed_over
              expect { get_direct_suggestion(prompt_data, 'generations') }
                .to raise_error(RuntimeError, "Unexpected status code 403")
            else
              response = get_direct_suggestion(prompt_data, 'generations')
              expect_status_code(403, response)
            end
          end
        end

        let(:prompt_data) do
          {
            prompt_version: 1,
            telemetry: [],
            current_file: {
              file_name: '/test.rb',
              content_above_cursor: content_above_cursor,
              content_below_cursor: "\n\n\n\n\n",
              language_identifier: 'ruby'
            },
            intent: 'completion'
          }.compact
        end

        let(:content_above_cursor) do
          <<-RUBY_PROMPT.chomp
            class Vehicle
              attr_accessor :make, :model, :year

              def drive
                puts "Driving the \#{make} \#{model} from \#{year}."
              end

              def reverse
                puts "Reversing the \#{make} \#{model} from \#{year}."
              end

              def honk_horn(sound)
                puts "Beep beep the \#{make} \#{model} from \#{year} is honking its horn. \#{sound}"
              end
            end

            vehicle = Vehicle.new
            vehicle.
          RUBY_PROMPT
        end

        # When incident_fail_over_completion_provider is enabled, getting the
        # connection details for a direct connection will return a 403
        # Since we need to check the feature flag to determine this we require
        # cannot run this spec on canary/production
        context 'on SaaS when direct connection', :smoke, :external_ai_provider,
          only: { pipeline: %w[staging-canary staging] } do
          include_examples 'direct code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/480822'
          include_examples 'direct code generation', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/487950'
        end

        context 'on Self-managed', :orchestrated do
          let(:token) { Runtime::User::Store.admin_api_client.personal_access_token }

          context 'with a valid license' do
            context 'with a Duo Enterprise add-on' do
              context 'when seat is assigned', :ai_gateway do
                include_examples 'direct code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/480823'
                include_examples 'direct code generation', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/487951'

                context 'with context' do
                  let(:prompt_data) { super().merge(context: context) }

                  include_examples 'direct code completion', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/491519'
                end
              end
            end
          end
        end
      end

      def get_indirect_suggestion(prompt_data)
        request_code_suggestion(url: "#{Runtime::Scenario.gitlab_address}/api/v4/code_suggestions/completions",
          token: token, prompt_data: prompt_data)
      end

      def get_direct_suggestion(prompt_data, type = 'completions')
        request_code_suggestion(url: "#{direct_access[:base_url]}/v2/code/#{type}", token: direct_access[:token],
          headers: direct_access[:headers], prompt_data: prompt_data)
      end

      def request_code_suggestion(url:, token:, prompt_data:, headers: {})
        response = Support::API.post(
          url,
          JSON.dump(prompt_data),
          headers: {
            Authorization: "Bearer #{token}",
            'Content-Type': 'application/json'
          }.merge(headers)
        )

        QA::Runtime::Logger.debug("Code Suggestion response: #{response}")
        response
      end

      def expect_status_code(expected_code, response)
        expect(response).not_to be_nil
        expect(response.code).to eq(expected_code),
          "Expected (#{expected_code}), request returned (#{response.code}): `#{response}`"
      end

      def verify_suggestion(response, expected_response_data)
        actual_response_data = parse_body(response)
        expect(actual_response_data).to match(a_hash_including(expected_response_data))

        suggestion = actual_response_data.dig(:choices, 0, :text)
        expect(suggestion).not_to be_nil, "The suggestion should not be nil, got: #{actual_response_data}"
        expect(suggestion.length).to be > 0, 'The suggestion should not be blank'
      end
    end
  end
end
