# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CascadeDuoFeaturesEnabledService, type: :service, feature_category: :ai_abstraction_layer do
  let(:duo_features_enabled) { true }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
  let_it_be_with_reload(:group2) { create(:group) }
  let_it_be_with_reload(:subgroup2) { create(:group, parent: group2) }
  let_it_be_with_reload(:project2) { create(:project, :repository, group: group2) }

  subject(:service) { described_class.new(duo_features_enabled) }

  describe '#cascade_for_group' do
    context 'when duo_features_enabled is true' do
      it 'updates subgroups and projects for given group to true' do
        # Initialize with duo_features_enabled: false
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: false) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: false) }

        service.cascade_for_group(group2)
        service.cascade_for_group(group)

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(true)
        expect(group.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(true)
        expect(project2.project_setting.duo_features_enabled).to be(true)
        expect(project.project_setting.duo_features_enabled).to be(true)
      end
    end

    context 'when duo_features_enabled is false' do
      let(:duo_features_enabled) { false }

      subject(:service) { described_class.new(duo_features_enabled) }

      it 'updates subgroups and projects for given groups to false' do
        # Initialize with duo_features_enabled: true
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: true) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: true) }

        service.cascade_for_group(group)

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(true)
        expect(group.namespace_settings.duo_features_enabled).to be(false)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(false)
        expect(project2.project_setting.duo_features_enabled).to be(true)
        expect(project.project_setting.duo_features_enabled).to be(false)
      end
    end
  end

  describe '#cascade_for_instance' do
    context 'when duo_features_enabled is true' do
      let(:duo_features_enabled) { true }

      subject(:service) { described_class.new(duo_features_enabled) }

      it 'updates all root groups, subgroups, and projects' do
        # Initialize with duo_features_enabled: false
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: false) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: false) }

        service.cascade_for_instance

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(true)
        expect(group.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(true)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(true)
        expect(project2.project_setting.duo_features_enabled).to be(true)
        expect(project.project_setting.duo_features_enabled).to be(true)
      end
    end

    context 'when duo_features_enabled is false' do
      let(:duo_features_enabled) { false }

      subject(:service) { described_class.new(duo_features_enabled) }

      it 'updates all root groups, subgroups, and projects' do
        # Initialize with duo_features_enabled: true
        [group2, subgroup2, group, subgroup].each { |g| g.namespace_settings.update!(duo_features_enabled: true) }
        [project2, project].each { |p| p.project_setting.update!(duo_features_enabled: true) }

        service.cascade_for_instance

        [group2, subgroup2, group, subgroup].each(&:reload)
        [project2, project].each(&:reload)

        expect(group2.namespace_settings.duo_features_enabled).to be(false)
        expect(group.namespace_settings.duo_features_enabled).to be(false)
        expect(subgroup2.namespace_settings.duo_features_enabled).to be(false)
        expect(subgroup.namespace_settings.duo_features_enabled).to be(false)
        expect(project2.project_setting.duo_features_enabled).to be(false)
        expect(project.project_setting.duo_features_enabled).to be(false)
      end
    end
  end
end
