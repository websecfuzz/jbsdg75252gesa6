# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::MergeRequestApprovalSettings::SettingsBuilder, feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  subject(:builder) do
    described_class.new(instance_value: instance_value, group_value: group_value, project_value: project_value)
  end

  describe '#locked?' do
    subject { builder.locked? }

    where(:instance_value, :group_value, :project_value, :result) do
      false | nil | nil | true
      true | nil  | nil | false
      true | false | nil | false
      true | nil | false | false
      true | nil | true | false
      true | true | true | false
      true | false | true | true
      false | false | true | true
    end

    with_them do
      it 'has the correct locked status' do
        is_expected.to eq(result)
      end
    end
  end

  describe '#value' do
    subject { builder.value }

    where(:instance_value, :group_value, :project_value, :result) do
      false | nil | nil | false
      true | nil  | nil | true
      true | false | nil | false
      true | nil | false | false
      true | nil | true | true
      true | true | true | true
      true | false | true | false
      false | false | true | false
      nil | true | true | true
      nil | true | false | false
      nil | false | true | false
      nil | true | nil | true
      nil | false | nil | false
      nil | nil | true | true
      nil | nil | false | false
    end

    with_them do
      it 'has the correct value' do
        is_expected.to eq(result)
      end
    end
  end

  describe '#inherited_from' do
    subject { builder.inherited_from }

    where(:instance_value, :group_value, :project_value, :result) do
      false | nil | nil | :instance
      true | nil  | nil | nil
      true | false | nil | nil
      true | nil | false | nil
      true | nil | true | nil
      true | true | true | nil
      true | false | true | :group
      false | false | true | :instance
    end

    with_them do
      it 'has the correct inherited from value' do
        is_expected.to eq(result)
      end
    end
  end

  describe '#to_settings' do
    subject { builder.to_settings }

    let(:instance_value) { false }
    let(:group_value) { true }
    let(:project_value) { nil }

    it 'builds a Setting object' do
      is_expected.to be_a(ComplianceManagement::MergeRequestApprovalSettings::Setting)
      is_expected.to have_attributes(value: false, locked: true, inherited_from: :instance)
    end
  end
end
