# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PlayBuildService, '#execute', feature_category: :continuous_integration do
  it_behaves_like 'restricts access to protected environments' do
    subject { described_class.new(current_user: user, build: build).execute }
  end

  it_behaves_like 'authorizing CI jobs' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:job) { create(:ci_build, :manual, pipeline: pipeline) }

    subject { described_class.new(current_user: user, build: job).execute }
  end
end
