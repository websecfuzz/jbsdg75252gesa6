# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountGroupsDuoAvailabilityMetric, feature_category: :service_ping do
  it 'raises an error with invalid duo_settings_value' do
    expect do
      described_class.new(options: { duo_settings_value: 'invalid' })
    end.to raise_error(ArgumentError, /Unknown parameters: duo_settings_value:invalid/)
  end

  context "when metric type is default_on" do
    context 'when there are no default_on groups' do
      it_behaves_like 'a correct instrumented metric value',
        { options: { duo_settings_value: 'default_on' } } do
          let(:expected_value) { 0 }
        end
    end

    context 'when there are default_on group' do
      let_it_be(:group) do
        create(:group, :with_duo_default_on)
      end

      it_behaves_like 'a correct instrumented metric value',
        { options: { duo_settings_value: 'default_on' } } do
          let(:expected_value) { 1 }
        end
    end
  end

  context "when metric type is default_off" do
    context 'when there are no default_off groups' do
      it_behaves_like 'a correct instrumented metric value',
        { options: { duo_settings_value: 'default_off' } } do
          let(:expected_value) { 0 }
        end
    end

    context 'when there are default_off group' do
      let_it_be(:group) do
        create(:group, :with_duo_default_off)
      end

      it_behaves_like 'a correct instrumented metric value',
        { options: { duo_settings_value: 'default_off' } } do
          let(:expected_value) { 1 }
        end
    end
  end

  context "when metric type is never_on" do
    context 'when there are no never_on groups' do
      it_behaves_like 'a correct instrumented metric value',
        { options: { duo_settings_value: 'never_on' } } do
          let(:expected_value) { 0 }
        end
    end

    context 'when there are never_on group' do
      let_it_be(:group) do
        create(:group, :with_duo_never_on)
      end

      it_behaves_like 'a correct instrumented metric value',
        { options: { duo_settings_value: 'never_on' } } do
          let(:expected_value) { 1 }
        end
    end
  end

  context "when multiple metric types exist" do
    let_it_be(:group1) do
      create_list(:group, 1, :with_duo_default_on)
    end

    let_it_be(:group2) do
      create_list(:group, 2, :with_duo_default_off)
    end

    let_it_be(:group3) do
      create_list(:group, 4, :with_duo_never_on)
    end

    it_behaves_like 'a correct instrumented metric value',
      { options: { duo_settings_value: 'default_on' } } do
        let(:expected_value) { 1 }
      end

    it_behaves_like 'a correct instrumented metric value',
      { options: { duo_settings_value: 'default_off' } } do
        let(:expected_value) { 2 }
      end

    it_behaves_like 'a correct instrumented metric value',
      { options: { duo_settings_value: 'never_on' } } do
        let(:expected_value) { 4 }
      end
  end
end
