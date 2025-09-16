# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CustomRoles::Definition, feature_category: :permissions do
  standard_yaml_files = Dir.glob(Rails.root.join("ee/config/custom_abilities/*.yml"))
  admin_yaml_files = Dir.glob(Rails.root.join("ee/config/custom_abilities/admin/*.yml"))

  def defined_abilities(files)
    files.map { |file| File.basename(file, '.yml').to_sym }
  end

  let_it_be(:defined_standard_abilities) { defined_abilities(standard_yaml_files) }
  let_it_be(:defined_admin_abilities) { defined_abilities(admin_yaml_files) }
  let_it_be(:all_defined_abilities) { defined_standard_abilities + defined_admin_abilities }

  describe '.all' do
    subject(:abilities) { described_class.all }

    it 'returns the defined abilities' do
      expect(abilities.keys).to match_array(all_defined_abilities)
    end

    it 'does not have overlapping role names' do
      admin_abilities = described_class.admin.keys
      standard_abilities = described_class.standard.keys

      expect(standard_abilities & admin_abilities).to be_empty
    end

    context 'when not initialized' do
      before do
        described_class.instance_variable_set(:@standard_definitions, nil)
        described_class.instance_variable_set(:@admin_definitions, nil)
        described_class.instance_variable_set(:@all_definitions, nil)
      end

      it 'reloads the abilities from the yaml files' do
        expect(described_class).to receive(:load_definitions)
          .with(described_class.send(:standard_path)).and_call_original
        expect(described_class).to receive(:load_definitions)
          .with(described_class.send(:admin_path)).and_call_original

        abilities
      end

      it 'returns the defined abilities' do
        expect(abilities.keys).to match_array(all_defined_abilities)
      end
    end
  end

  describe '.admin' do
    subject(:abilities) { described_class.admin }

    it 'returns the defined abilities' do
      expect(abilities.keys).to match_array(defined_admin_abilities)
    end
  end

  describe '.standard' do
    subject(:abilities) { described_class.standard }

    it 'returns the defined abilities' do
      expect(abilities.keys).to match_array(defined_standard_abilities)
    end
  end

  describe '.load_abilities!' do
    before do
      described_class.instance_variable_set(:@standard_definitions, { old_std: 'ability' })
      described_class.instance_variable_set(:@admin_definitions, { old_admin: 'ability' })
      described_class.instance_variable_set(:@all_definitions, { old_std: 'ability', old_admin: 'ability' })
    end

    it 'returns the defined abilities' do
      expect { described_class.load_abilities! }.to change { described_class.admin.keys }
        .from(%i[old_admin]).to(array_including(defined_admin_abilities)).and change { described_class.standard.keys }
        .from(%i[old_std]).to(array_including(defined_standard_abilities)).and change { described_class.all.keys }
        .from(%i[old_std old_admin]).to(array_including(all_defined_abilities))
    end
  end

  describe 'validations' do
    let(:validator) { JSONSchemer.schema(Pathname.new(Rails.root.join(validator_path))) }

    def validate(ability_file)
      data = YAML.load_file(ability_file)
      validator.validate(data).pluck('error')
    end

    describe 'for standard abilities' do
      let(:validator_path) { 'ee/config/custom_abilities/type_schema.json' }

      standard_yaml_files.each do |ability_file|
        it "validates #{ability_file}" do
          expect(validate(ability_file)).to be_empty
        end
      end
    end

    describe 'for admin abilities' do
      let(:validator_path) { 'ee/config/custom_abilities/admin/type_schema.json' }

      admin_yaml_files.each do |ability_file|
        it "validates #{ability_file}" do
          expect(validate(ability_file)).to be_empty
        end
      end
    end
  end
end
