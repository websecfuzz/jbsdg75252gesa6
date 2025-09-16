# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::FeatureFlagEnabler, feature_category: :duo_chat do
  it 'enables feature flags by group ai framework' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::ai framework', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group code creation' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::code creation', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group duo chat' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::duo chat', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group duo workflow' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::duo workflow', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group custom models' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::custom models', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end
end
