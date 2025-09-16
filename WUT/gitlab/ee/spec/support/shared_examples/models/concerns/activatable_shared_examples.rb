# frozen_string_literal: true

RSpec.shared_examples 'includes Activatable concern' do
  describe 'active/inactive functionality' do
    let(:valid_model) { create(model_factory_name) } # rubocop:disable Rails/SaveBang -- Just for example

    it { is_expected.to be_a(AuditEvents::Activatable) }

    describe '.active scope' do
      it 'returns only active records' do
        active_model = create(model_factory_name, active: true)
        create(model_factory_name, active: false)

        expect(described_class.active).to contain_exactly(active_model)
      end
    end

    describe '#active?' do
      it 'returns true for active records' do
        model = create(model_factory_name, active: true)
        expect(model.active?).to be true
      end

      it 'returns false for inactive records' do
        model = create(model_factory_name, active: false)
        expect(model.active?).to be false
      end
    end

    describe '#activate!' do
      it 'sets active to true' do
        model = create(model_factory_name, active: false)

        model.activate!

        expect(model.active).to be true
      end
    end

    describe '#deactivate!' do
      it 'sets active to false' do
        model = create(model_factory_name, active: true)

        model.deactivate!

        expect(model.active).to be false
      end
    end
  end
end
