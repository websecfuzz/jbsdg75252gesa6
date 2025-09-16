# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro::LeadFormComponent, :saas, :aggregate_failures, type: :component, feature_category: :acquisition do
  let(:additional_kwargs) { {} }

  it_behaves_like described_class
end
