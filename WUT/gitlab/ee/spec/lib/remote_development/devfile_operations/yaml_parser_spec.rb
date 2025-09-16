# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::DevfileOperations::YamlParser, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:devfile_yaml) { example_devfile_yaml }
  let(:expected_devfile) { yaml_safe_load_symbolized(devfile_yaml) }
  let(:context) { { devfile_yaml: devfile_yaml } }

  subject(:result) do
    described_class.parse(context)
  end

  it "merges devfile to passed context" do
    expect(result).to eq(
      Gitlab::Fp::Result.ok(
        context.merge({
          devfile: expected_devfile
        })
      )
    )
  end

  context "when devfile YAML cannot be loaded" do
    let(:devfile_path) { ".devfile.yaml" }
    let(:devfile_yaml) { "invalid: yaml: boom" }

    it "returns an err Result containing error details" do
      message = result.unwrap_err
      expect(message).to be_a(RemoteDevelopment::Messages::DevfileYamlParseFailed)
      message.content => { details: String => error_details }
      expect(error_details).to match(/Devfile YAML could not be parsed: .*mapping values are not allowed/i)
    end
  end

  context "when devfile YAML is valid but is invalid JSON" do
    let(:devfile_path) { ".devfile.yaml" }
    let(:devfile_yaml) { "!binary key: value" }

    it "returns an err Result containing error details" do
      message = result.unwrap_err
      expect(message).to be_a(RemoteDevelopment::Messages::DevfileYamlParseFailed)
      message.content => { details: String => error_details, context: Hash => actual_context }
      # TODO: Performing an exact search of the error "Devfile YAML could not be parsed: Invalid Unicode \[91 ec\] at 0"
      #       fails when we run "scripts/remote_development/run-smoke-test-suite.sh" . Hence, to keep the script
      #       functional until we fix the issue in https://gitlab.com/gitlab-org/gitlab/-/issues/546355 ,
      #       the regex match has been shortened.
      expect(error_details).to match(/Devfile YAML could not be parsed: /i)
      expect(actual_context).to eq(context)
    end
  end
end
