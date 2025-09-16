# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt, feature_category: :global_search do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be_with_reload(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group) }
  let_it_be_with_reload(:index) do
    create(:zoekt_index, :ready, zoekt_enabled_namespace: enabled_namespace, node: node)
  end

  let_it_be(:unassigned_group) { create(:group) }
  let_it_be_with_reload(:enabled_namespace_without_index) do
    create(:zoekt_enabled_namespace, namespace: unassigned_group)
  end

  describe '.search?' do
    before do
      stub_licensed_features(zoekt_code_search: true)
      stub_ee_application_setting(zoekt_search_enabled: true)
    end

    subject(:search) { described_class.search?(container) }

    [true, false].each do |search|
      context "when search on the zoekt_enabled_namespace is set to #{search}" do
        before do
          enabled_namespace.update!(search: search)
        end

        context 'when passed a project' do
          let(:container) { project }

          it { is_expected.to eq(search) }
        end
      end
    end

    context 'when no indices are ready' do
      let(:container) { project }

      before do
        index.update!(state: :initializing)
      end

      it { is_expected.to be(false) }
    end

    context 'when container is namespace' do
      let(:container) { group }

      context 'and there is no replica with ready state' do
        before do
          enabled_namespace.replicas.update_all(state: :pending)
        end

        it { is_expected.to be(false) }
      end

      context 'and there is at-least one replica with the ready state' do
        before do
          enabled_namespace.replicas.first.ready!
        end

        it { is_expected.to be(true) }

        context 'when zoekt_enabled_namespace search is false' do
          before do
            enabled_namespace.update!(search: false)
          end

          it { is_expected.to be(false) }
        end
      end
    end

    context 'when Zoekt::EnabledNamespace not found' do
      let(:container) { build(:project) }

      it { is_expected.to be(false) }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { search }.to raise_error(ArgumentError) }
    end
  end

  describe '.index?' do
    before do
      stub_licensed_features(zoekt_code_search: true)
      stub_ee_application_setting(zoekt_indexing_enabled: true)
    end

    subject(:index) { described_class.index?(container) }

    context 'when passed a project' do
      let(:container) { project }

      it { is_expected.to be(true) }
    end

    context 'when passed a namespace' do
      let(:container) { group }

      it { is_expected.to be(true) }
    end

    context 'when passed a root namespace id' do
      let(:container) { group.id }

      it { is_expected.to be(true) }
    end

    context 'when Zoekt::Index is not found' do
      let(:container) { build(:project) }

      it { is_expected.to be(false) }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { index }.to raise_error(ArgumentError) }
    end

    context 'when group is unassigned' do
      let(:container) { unassigned_group }

      it { is_expected.to be(false) }
    end
  end

  describe '.licensed_and_indexing_enabled?' do
    subject { described_class.licensed_and_indexing_enabled? }

    context 'when license feature zoekt_code_search is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when application setting zoekt_indexing_enabled is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when license feature zoekt_code_search and zoekt_indexing_enabled are enabled' do
      before do
        stub_licensed_features(zoekt_code_search: true)
        stub_ee_application_setting(zoekt_indexing_enabled: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.enabled?' do
    subject { described_class.enabled? }

    context 'when license feature zoekt_code_search is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when application setting zoekt_search_enabled? is disabled' do
      before do
        stub_ee_application_setting(zoekt_search_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when license feature zoekt_code_search and application setting zoekt_search_enabled is enabled' do
      before do
        stub_licensed_features(zoekt_code_search: true)
        stub_ee_application_setting(zoekt_search_enabled: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.enabled_for_user?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:a_user) { create(:user) }

    subject(:enabled_for_user) { described_class.enabled_for_user?(user) }

    before do
      stub_ee_application_setting(zoekt_search_enabled: setting_zoekt_search_enabled)
      stub_licensed_features(zoekt_code_search: license_setting)

      allow(a_user).to receive(:enabled_zoekt?).and_return(user_setting)
    end

    where(:user, :setting_zoekt_search_enabled, :license_setting, :user_setting, :expected_result) do
      ref(:a_user) | true   | true  | true  | true
      ref(:a_user) | true   | true  | false | false
      ref(:a_user) | true   | false | true  | false
      ref(:a_user) | false  | true  | true  | false
      nil          | true   | true  | true  | true
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end

  describe '.index_async' do
    subject(:index_async) { described_class.index_async(project.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(index_async).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      it 'calls IndexingTaskWorker async' do
        expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async).with(project.id, :index_repo)

        index_async
      end
    end
  end

  describe '.index_in' do
    subject(:index_in) { described_class.index_in(1.second, project.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(index_in).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      it 'calls IndexingTaskWorker async' do
        expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
          .with(project.id, :index_repo, { delay: 1.second })

        index_in
      end
    end
  end

  describe '.delete_async' do
    subject(:delete_async) { described_class.delete_async(project.id, root_namespace_id: group.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(delete_async).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      context 'when node_id is not provided' do
        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id })

          delete_async
        end
      end

      context 'when node_id is provided' do
        subject(:delete_async) do
          described_class.delete_async(project.id, root_namespace_id: group.id, node_id: node.id)
        end

        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id })

          delete_async
        end
      end
    end
  end

  describe '.delete_in' do
    subject(:delete_in) { described_class.delete_in(1.second, project.id, root_namespace_id: group.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(delete_in).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      context 'when node_id is not provided' do
        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id, delay: 1.second })

          delete_in
        end
      end

      context 'when node_id is provided' do
        subject(:delete_in) do
          described_class.delete_in(2.seconds, project.id, root_namespace_id: group.id, node_id: node.id)
        end

        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id, delay: 2.seconds })

          delete_in
        end
      end
    end
  end

  describe '.bin_path' do
    subject { described_class.bin_path }

    it { is_expected.to eq('tmp/tests/gitlab-zoekt/bin/gitlab-zoekt') }
  end
end
