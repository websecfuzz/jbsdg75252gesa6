# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'pipeline_execution_schedule_policy_content.json', feature_category: :security_policy_management do
  let(:schema_path) do
    Rails.root.join("ee/app/validators/json_schemas/pipeline_execution_schedule_policy_content.json")
  end

  let(:schema) { JSONSchemer.schema(schema_path) }
  let(:policy) do
    {
      content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
      schedules: [{
        type: "daily",
        start_time: "00:00",
        time_window: { distribution: "random", value: 4000 }
      }]
    }
  end

  context 'when policy has no branches' do
    specify { expect(schema.valid?(policy)).to be true }
  end

  context 'when policy has branches' do
    before do
      policy[:schedules][0][:branches] = branches
    end

    context 'with a valid list of branches' do
      let(:branches) { %w[main develop feature-branch] }

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'with an empty list of branches' do
      let(:branches) { [] }

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'with too many branches' do
      let(:branches) { %w[branch1 branch2 branch3 branch4 branch5 branch6] }

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'with duplicated branches' do
      let(:branches) { %w[main main develop] }

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'with non-string branches' do
      let(:branches) { ["main", 123, "develop"] }

      specify { expect(schema.valid?(policy)).to be false }
    end
  end
end
