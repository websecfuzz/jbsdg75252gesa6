# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineEntity, feature_category: :continuous_integration do
  let(:project_namespace) { build_stubbed(:project_namespace) }
  let(:project) { build_stubbed(:project, project_namespace: project_namespace) }
  let(:user) { build_stubbed(:user) }
  let(:pipeline) { build_stubbed(:ci_empty_pipeline, project: project) }
  let(:request) { double('request', current_user: user, project: project) }
  let(:entity) { described_class.represent(pipeline, request: request) }

  describe '#as_json' do
    subject { entity.as_json }

    it 'contains flags' do
      expect(subject).to include :flags
      expect(subject[:flags]).to include :merge_train_pipeline
    end
  end
end
