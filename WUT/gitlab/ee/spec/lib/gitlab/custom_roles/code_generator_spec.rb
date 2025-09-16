# frozen_string_literal: true

require 'spec_helper'
require 'active_support/testing/stream'

RSpec.describe Gitlab::CustomRoles::CodeGenerator, :silence_stdout,
  feature_category: :permissions do
  include ActiveSupport::Testing::Stream

  before do
    allow(MemberRole).to receive(:all_customizable_permissions).and_return(
      { test_new_ability: { feature_category: 'vulnerability_management' } }
    )
  end

  let(:ability) { 'test_new_ability' }
  let(:config) { { destination_root: destination_root } }
  let(:args) { ['--ability', ability] }

  subject(:run_generator) { described_class.start(args, config) }

  context 'when the ability is not yet defined' do
    let(:ability) { 'non_existing_ability' }

    it 'raises an error' do
      expect { run_generator }.to raise_error(ArgumentError)
    end
  end

  context 'when the ability exists' do
    after do
      FileUtils.rm_rf(destination_root)
    end

    let(:schema_file_path) { 'app/validators/json_schemas/member_role_permissions.json' }
    let(:schema) do
      Gitlab::Json.pretty_generate(
        '$schema': 'http://json-schema.org/draft-07/schema#',
        description: 'Permissions on custom roles',
        type: 'object',
        additionalProperties: false,
        properties: {
          test_new_ability: { type: 'boolean' }
        }
      )
    end

    it 'updates the schema validation file with the right content' do
      expect(File).to receive(:write).with(schema_file_path, "#{schema}\n")

      run_generator
    end
  end

  def destination_root
    File.expand_path("../tmp", __dir__)
  end
end
