# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRepository, feature_category: :geo_replication do
  include_examples 'a verifiable model with a separate table for verification state' do
    let(:verifiable_model_record) { build(:container_repository) }
    let(:unverifiable_model_record) { nil }
  end

  describe '.replicables_for_current_secondary' do
    let(:secondary) { create(:geo_node, :secondary) }

    let_it_be(:synced_group) { create(:group) }
    let_it_be(:nested_group) { create(:group, parent: synced_group) }
    let_it_be(:synced_project) { create(:project, group: synced_group) }
    let_it_be(:synced_project_in_nested_group) { create(:project, group: nested_group) }
    let_it_be(:unsynced_project) { create(:project) }
    let_it_be(:project_broken_storage) { create(:project, :broken_storage) }

    let_it_be(:container_repository_1) { create(:container_repository, project: synced_project) }
    let_it_be(:container_repository_2) { create(:container_repository, project: synced_project_in_nested_group) }
    let_it_be(:container_repository_3) { create(:container_repository, project: unsynced_project) }
    let_it_be(:container_repository_4) { create(:container_repository, project: project_broken_storage) }

    before do
      stub_current_geo_node(secondary)
      stub_registry_replication_config(enabled: true)
    end

    context 'with registry replication disabled' do
      before do
        stub_registry_replication_config(enabled: false)
      end

      it 'returns an empty relation' do
        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to be_empty
      end
    end

    context 'without selective sync' do
      it 'returns all container repositories' do
        expected = [container_repository_1, container_repository_2, container_repository_3, container_repository_4]

        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to match_array(expected)
      end
    end

    context 'with selective sync by namespace' do
      before do
        secondary.update!(selective_sync_type: 'namespaces', namespaces: [synced_group])
      end

      it 'excludes container repositories that are not in selectively synced projects' do
        expected = [container_repository_1, container_repository_2]

        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to match_array(expected)
      end
    end

    context 'with selective sync by shard' do
      before do
        secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['broken'])
      end

      it 'excludes container repositories that are not in selectively synced shards' do
        expected = [container_repository_4]

        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to match_array(expected)
      end
    end
  end

  describe '.search' do
    let_it_be(:container_repository1) { create(:container_repository) }
    let_it_be(:container_repository2) { create(:container_repository) }
    let_it_be(:container_repository3) { create(:container_repository) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(container_repository1, container_repository2, container_repository3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all container repositories' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with matches by attributes' do
          where(:searchable_attributes) { described_class::EE_SEARCHABLE_ATTRIBUTES }

          before do
            # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
            container_repository1.update_column(searchable_attributes, 'any_keyword')
          end

          with_them do
            it do
              result = described_class.search('any_keyword')

              expect(result).to contain_exactly(container_repository1)
            end
          end
        end
      end
    end
  end

  describe '#push_blob' do
    it "calls client's push blob with path passed" do
      gitlab_container_repository = create(:container_repository)
      client = instance_double("ContainerRegistry::Client")
      allow(gitlab_container_repository).to receive(:client).and_return(client)

      expect(client).to receive(:push_blob).with(gitlab_container_repository.path, 'a123cd', ['body'], 32456)

      gitlab_container_repository.push_blob('a123cd', ['body'], 32456)
    end
  end

  describe '#protected_from_delete_by_tag_rules?' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:project) { create(:project, path: 'test') }
    let_it_be_with_refind(:repository) do
      create(:container_repository, name: 'my_image', project: project)
    end

    subject { repository.protected_from_delete_by_tag_rules?(current_user) }

    context 'when the user is nil' do
      let(:current_user) { nil }

      it { is_expected.to be_truthy }
    end

    context 'when immutable tag rules are present' do
      before_all do
        create(
          :container_registry_protection_tag_rule,
          :immutable,
          tag_name_pattern: 'tag',
          project: project
        )
      end

      context 'when the licensed feature is enabled' do
        before do
          allow(repository).to receive(:has_tags?).and_return(has_tags)
          stub_licensed_features(container_registry_immutable_tag_rules: true)
        end

        let(:has_tags) { true }

        it { is_expected.to be(true) }

        context 'when no tags' do
          let(:has_tags) { false }

          it { is_expected.to be(false) }
        end
      end

      context 'when the licensed feature is not enabled' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it_behaves_like 'checking mutable tag rules on a container repository'
      end
    end

    context 'when there are no immutable tag rules' do
      it_behaves_like 'checking mutable tag rules on a container repository'
    end
  end
end
