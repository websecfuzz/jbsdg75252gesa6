# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreateDownstreamPipelineService, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:upstream_project) { create(:project, :repository) }
  let_it_be(:upstream_pipeline) { create(:ci_pipeline, :created, project: upstream_project) }

  let(:trigger) do
    {
      trigger: {
        project: downstream_project.full_path,
        branch: 'feature'
      }
    }
  end

  let(:bridge) do
    create(
      :ci_bridge,
      status: :pending,
      user: user,
      options: trigger,
      pipeline: upstream_pipeline
    )
  end

  let(:service) { described_class.new(upstream_project, user) }

  before do
    stub_ci_pipeline_yaml_file(YAML.dump(rspec: { script: 'rspec' }))
    allow(::Gitlab::Audit::Auditor).to receive(:audit)
  end

  subject(:execute) { service.execute(bridge) }

  context 'when multi project downstream pipeline is created' do
    let_it_be(:downstream_project) { create(:project, :repository) }

    before_all do
      upstream_project.add_developer(user)
      downstream_project.add_developer(user)
    end

    it 'calls auditor with correct args' do
      pipeline = execute.payload

      expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
        name: "multi_project_downstream_pipeline_created",
        author: user,
        scope: pipeline.project,
        target: pipeline,
        target_details: pipeline.id.to_s,
        message: "Multi-project downstream pipeline created.",
        additional_details: {
          upstream_root_pipeline_id: upstream_pipeline.id,
          upstream_root_project_path: upstream_pipeline.project.full_path
        }
      )
    end
  end

  context 'when parent child project downstream pipeline is created' do
    let_it_be(:downstream_project) { upstream_project }

    before_all do
      upstream_project.add_developer(user)
      downstream_project.add_developer(user)
    end

    it 'does not calls auditor' do
      execute.payload

      expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
    end
  end
end
