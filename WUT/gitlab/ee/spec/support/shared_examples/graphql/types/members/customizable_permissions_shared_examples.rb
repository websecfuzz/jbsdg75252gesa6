# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'graphql customizable permission' do
  let(:permission_name) { :read_code }
  let(:permission_attrs) { { description: 'read code', milestone: '17.10' } }

  describe '.define_permission' do
    let(:feature_flag) { nil }

    subject(:define_permission) do
      described_class.define_permission(permission_name, permission_attrs, feature_flag: feature_flag)
    end

    context 'for feature flagged permissions' do
      context 'for a default feature flag' do
        before do
          allow(::Feature::Definition).to receive(:get).with("custom_ability_#{permission_name}").and_return(true)
        end

        it 'is experimental' do
          expect(define_permission.deprecation_reason).to include('Experiment')
        end
      end

      context 'for a custom feature flag' do
        let(:feature_flag) { :custom_permission_feature_in_dev }

        before do
          allow(::Feature::Definition).to receive(:get).and_call_original
          allow(::Feature::Definition).to receive(:get).with(feature_flag).and_return(true)
        end

        it 'is experimental' do
          expect(define_permission.deprecation_reason).to include('Experiment')
        end
      end
    end

    context 'for non-feature flagged permissions' do
      it 'is not experimental' do
        expect(define_permission.deprecation_reason).to be_nil
      end
    end
  end
end
