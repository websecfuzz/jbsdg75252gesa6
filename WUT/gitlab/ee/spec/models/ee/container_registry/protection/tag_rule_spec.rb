# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::TagRule, type: :model, feature_category: :container_registry do
  shared_examples 'returning same result for different access levels' do |expected_result|
    where(:user_access_level) do
      [
        Gitlab::Access::MAINTAINER,
        Gitlab::Access::OWNER,
        Gitlab::Access::ADMIN
      ]
    end

    with_them do
      it { is_expected.to be(expected_result) }
    end
  end

  describe 'validations' do
    describe '#validate_access_levels' do
      subject(:tag_rule) { described_class.new(attributes) }

      let(:minimum_access_level_for_delete) { Gitlab::Access::ADMIN }
      let(:minimum_access_level_for_push) { Gitlab::Access::OWNER }
      let(:attributes) do
        {
          tag_name_pattern: '.*',
          minimum_access_level_for_delete: minimum_access_level_for_delete,
          minimum_access_level_for_push: minimum_access_level_for_push
        }
      end

      context 'when both access levels are nil' do
        let(:minimum_access_level_for_delete) { nil }
        let(:minimum_access_level_for_push) { nil }

        it 'is valid' do
          expect(tag_rule).to be_valid
        end
      end
    end
  end

  describe '.for_actions_and_access' do
    let_it_be(:rule) { create(:container_registry_protection_tag_rule, :immutable) }

    let(:actions) { %w[push delete] }
    let(:user_access_level) { Gitlab::Access::MAINTAINER }

    subject { described_class.for_actions_and_access(actions, user_access_level, include_immutable:) }

    context 'when include_immutable is true' do
      let(:include_immutable) { true }

      it { is_expected.to include(rule) }
    end

    context 'when include_immutable is false' do
      let(:include_immutable) { false }

      it { is_expected.not_to include(rule) }
    end
  end

  describe '.for_delete_and_access' do
    let_it_be(:rule) { create(:container_registry_protection_tag_rule, :immutable) }

    let(:user_access_level) { Gitlab::Access::MAINTAINER }

    subject { described_class.for_delete_and_access(user_access_level, include_immutable:) }

    context 'when include_immutable is true' do
      let(:include_immutable) { true }

      it { is_expected.to include(rule) }
    end

    context 'when include_immutable is false' do
      let(:include_immutable) { false }

      it { is_expected.not_to include(rule) }
    end
  end

  describe '#immutable?' do
    subject { rule.immutable? }

    context 'when access levels are nil' do
      let(:rule) do
        build(
          :container_registry_protection_tag_rule,
          minimum_access_level_for_push: nil,
          minimum_access_level_for_delete: nil
        )
      end

      it { is_expected.to be(true) }
    end

    context 'when access levels are not nil' do
      let(:rule) do
        build(
          :container_registry_protection_tag_rule,
          minimum_access_level_for_push: ::Gitlab::Access::OWNER,
          minimum_access_level_for_delete: ::Gitlab::Access::OWNER
        )
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#push_restricted?' do
    subject { rule.push_restricted?(user_access_level) }

    before do
      stub_licensed_features(container_registry_immutable_tag_rules: true)
    end

    context 'for an immutable tag rule' do
      let_it_be(:rule) { build(:container_registry_protection_tag_rule, :immutable) }

      it_behaves_like 'returning same result for different access levels', true

      context 'when the feature is not licensed' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it_behaves_like 'returning same result for different access levels', false
      end
    end
  end

  describe '#delete_restricted?' do
    subject { rule.delete_restricted?(user_access_level) }

    before do
      stub_licensed_features(container_registry_immutable_tag_rules: true)
    end

    context 'for an immutable tag rule' do
      let_it_be(:rule) { build(:container_registry_protection_tag_rule, :immutable) }

      it_behaves_like 'returning same result for different access levels', true

      context 'when the feature is not licensed' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it_behaves_like 'returning same result for different access levels', false
      end
    end
  end

  describe '#can_be_deleted?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }

    subject { rule.can_be_deleted?(user) }

    context 'when the rule is immutable' do
      let_it_be(:rule) { build(:container_registry_protection_tag_rule, :immutable, project:) }

      where(:user_role, :expected_result) do
        :developer   | false
        :maintainer  | false
        :owner       | true
      end

      with_them do
        before do
          project.send(:"add_#{user_role}", user)
        end

        it { is_expected.to be(expected_result) }
      end
    end
  end
end
