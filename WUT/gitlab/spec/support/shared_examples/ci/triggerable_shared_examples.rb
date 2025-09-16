# frozen_string_literal: true

RSpec.shared_examples 'a triggerable processable' do |factory|
  describe '#variables' do
    subject { described_instance.variables }

    let_it_be(:described_instance) { create(factory) } # rubocop:disable Rails/SaveBang -- This is a factory, not a Rails method call

    context 'when trigger is present' do
      let_it_be(:trigger) { create(:ci_trigger, project: project) }

      let(:predefined_trigger_variables) do
        [
          { key: 'CI_PIPELINE_TRIGGERED', value: 'true', public: true, masked: false },
          { key: 'CI_TRIGGER_SHORT_TOKEN', value: trigger.short_token, public: true, masked: false }
        ]
      end

      before do
        described_instance.trigger = trigger
      end

      it { is_expected.to include(*predefined_trigger_variables) }
    end
  end
end
