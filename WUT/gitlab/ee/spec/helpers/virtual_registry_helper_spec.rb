# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistryHelper, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  describe '#registry_types' do
    let(:group) { build_stubbed(:group) }

    subject(:registry_types) { helper.registry_types(group, registry_types_with_counts) }

    context 'when there are available registry types' do
      let(:registry_types_with_counts) { { maven: 3 } }

      it 'returns the correct structure for registry types' do
        expect(registry_types).to be_a(Hash)
        expect(registry_types.keys).to contain_exactly(:maven)

        expect(registry_types[:maven]).to include(
          new_page_path: a_string_matching(%r{virtual_registries/maven/new}),
          landing_page_path: a_string_matching(%r{virtual_registries/maven}),
          image_path: 'illustrations/logos/maven.svg',
          count: 3,
          type_name: 'Maven'
        )
      end
    end
  end

  describe '#can_create_virtual_registry?' do
    let(:group) { build_stubbed(:group) }
    let(:user) { build_stubbed(:user) }
    let(:policy_subject) { instance_double(::VirtualRegistries::Packages::Policies::Group) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(group).to receive(:virtual_registry_policy_subject).and_return(policy_subject)
      allow(Ability).to receive(:allowed?).with(user, :create_virtual_registry,
        policy_subject).and_return(allow_create_virtual_registry)
    end

    subject { helper.can_create_virtual_registry?(group) }

    where(:allow_create_virtual_registry, :result) do
      true  | true
      false | false
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#can_destroy_virtual_registry?' do
    let(:group) { build_stubbed(:group) }
    let(:user) { build_stubbed(:user) }
    let(:policy_subject) { instance_double(::VirtualRegistries::Packages::Policies::Group) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(group).to receive(:virtual_registry_policy_subject).and_return(policy_subject)
      allow(Ability).to receive(:allowed?).with(user, :destroy_virtual_registry,
        policy_subject).and_return(allow_destroy_virtual_registry)
    end

    subject { helper.can_destroy_virtual_registry?(group) }

    where(:allow_destroy_virtual_registry, :result) do
      true  | true
      false | false
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#maven_registries_data' do
    let(:group) { build_stubbed(:group) }

    it 'returns maven registries JSON data' do
      json_data = ::Gitlab::Json.parse(helper.maven_registries_data(group))
      expect(json_data).to include(
        'fullPath' => group.full_path,
        'editPathTemplate' => edit_group_virtual_registries_maven_registry_path(group, ':id'),
        'showPathTemplate' => group_virtual_registries_maven_registry_path(group, ':id')
      )
    end
  end

  describe '#delete_registry_modal_data' do
    let(:maven_registry) do
      build_stubbed(:virtual_registries_packages_maven_registry, group: group, name: 'test-registry')
    end

    let(:group) { build_stubbed(:group) }

    subject(:modal_data) { helper.delete_registry_modal_data(group, maven_registry) }

    it 'returns the JSON data for modal to delete registry' do
      expect(modal_data).to eq({
        path: group_virtual_registries_maven_registry_path(group, maven_registry),
        method: 'delete',
        modal_attributes: {
          title: 'Delete Maven registry',
          size: 'sm',
          messageHtml: 'Are you sure you want to delete <strong>test-registry</strong>?',
          okVariant: 'danger',
          okTitle: 'Delete'
        }
      })
    end
  end

  describe '#edit_upstream_template_data' do
    let(:maven_upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }
    let(:maven_upstream_attributes) do
      {
        'id' => maven_upstream.id,
        'name' => maven_upstream.name,
        'username' => maven_upstream.username,
        'url' => maven_upstream.url,
        'description' => maven_upstream.description,
        'cacheValidityHours' => maven_upstream.cache_validity_hours
      }
    end

    before do
      allow(helper).to receive(:maven_upstream_attributes).with(maven_upstream).and_return(maven_upstream_attributes)
    end

    subject { helper.edit_upstream_template_data(maven_upstream) }

    it 'returns maven upstream edit template data' do
      json_data = ::Gitlab::Json.parse(helper.edit_upstream_template_data(maven_upstream))
      expect(json_data).to include(
        'upstream' => maven_upstream_attributes,
        'registriesPath' =>
          group_virtual_registries_path(maven_upstream.group),
        'upstreamPath' =>
          group_virtual_registries_maven_upstream_path(maven_upstream.group, maven_upstream)
      )
    end
  end
end
