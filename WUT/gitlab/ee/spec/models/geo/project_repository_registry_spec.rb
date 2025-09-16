# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryRegistry, :geo, type: :model, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:registry) { build(:geo_project_repository_registry) }

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'

  describe '.repository_out_of_date?' do
    let_it_be(:project) { create(:project) }

    context 'for a non-Geo setup' do
      it 'returns false' do
        expect(described_class.repository_out_of_date?(project.id)).to be_falsey
      end
    end

    context 'for a Geo setup' do
      before do
        stub_current_geo_node(current_node)
      end

      context 'for a Geo Primary' do
        let(:current_node) { create(:geo_node, :primary) }

        it 'returns false' do
          expect(described_class.repository_out_of_date?(project.id)).to be_falsey
        end
      end

      context 'for a Geo secondary' do
        let(:current_node) { create(:geo_node) }

        context 'when Primary node is not configured' do
          it 'returns false' do
            expect(described_class.repository_out_of_date?(project.id)).to be_falsey
          end
        end

        context 'when Primary node is configured' do
          before do
            create(:geo_node, :primary)
          end

          context 'when project_repository_registry entry does not exist' do
            it 'returns true' do
              expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                message: "out-of-date", reason: "registry doesn't exist"))

              expect(described_class.repository_out_of_date?(project.id)).to be_truthy
            end
          end

          context 'when project_repository_registry entry does exist' do
            context 'when last_repository_updated_at is not set' do
              it 'returns false' do
                registry = create(:geo_project_repository_registry, :synced, project: project)
                registry.project.update!(last_repository_updated_at: nil)

                expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                  message: "up-to-date", reason: "there is no timestamp for the latest change to the repo"))

                expect(described_class.repository_out_of_date?(registry.project_id)).to be_falsey
              end
            end

            context 'when synchronous_request_required is true' do
              let_it_be(:project) { create(:project, :pipeline_refs) }
              let(:registry) { create(:geo_project_repository_registry, :verification_succeeded, project: project) }
              let(:secondary_pipeline_refs) { Array.new(10) { |x| "refs/pipelines/#{x}" } }
              let(:some_secondary_pipeline_refs) { Array.new(9) { |x| "refs/pipelines/#{x}" } }

              context 'when the primary has pipeline refs the secondary does not have' do
                let_it_be(:project) { create(:project, :pipeline_refs, pipeline_count: 9) }

                it 'returns true' do
                  allow(::Gitlab::Geo).to receive(:primary_pipeline_refs)
                    .with(registry.project_id).and_return(secondary_pipeline_refs)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "secondary is missing pipeline refs"))

                  expect(described_class.repository_out_of_date?(registry.project_id, true)).to be_truthy
                end
              end

              context 'when the secondary has pipeline refs the primary does not have' do
                it 'returns false' do
                  allow(::Gitlab::Geo).to receive(:primary_pipeline_refs)
                    .with(registry.project_id).and_return(some_secondary_pipeline_refs)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "up-to-date", reason: "secondary has all pipeline refs"))

                  expect(described_class.repository_out_of_date?(registry.project_id, true)).to be_falsey
                end
              end

              context 'when pipeline refs are the same on primary and secondary' do
                it 'returns false' do
                  allow(::Gitlab::Geo).to receive(:primary_pipeline_refs)
                    .with(registry.project_id).and_return(secondary_pipeline_refs)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "up-to-date", reason: "secondary has all pipeline refs"))

                  expect(described_class.repository_out_of_date?(registry.project_id, true)).to be_falsey
                end
              end
            end

            context 'when last_repository_updated_at is set' do
              context 'when sync failed' do
                it 'returns true' do
                  registry = create(:geo_project_repository_registry, :failed, project: project)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "sync failed"))

                  expect(described_class.repository_out_of_date?(registry.project_id)).to be_truthy
                end
              end

              context 'when last_synced_at is not set' do
                it 'returns true' do
                  registry = create(:geo_project_repository_registry, project: project, last_synced_at: nil)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "it has never been synced"))

                  expect(described_class.repository_out_of_date?(registry.project_id)).to be_truthy
                end
              end

              context 'when verification failed' do
                it 'returns true' do
                  registry = create(:geo_project_repository_registry, :verification_failed, project: project)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "not verified yet"))

                  expect(described_class.repository_out_of_date?(registry.project_id)).to be_truthy
                end
              end

              context 'when verification succeeded' do
                it 'returns false' do
                  registry = create(:geo_project_repository_registry, :verification_succeeded,
                    project: project, last_synced_at: Time.current + 5.minutes)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "up-to-date", reason: "last successfully synced after latest change"))

                  expect(described_class.repository_out_of_date?(registry.project_id)).to be_falsey
                end
              end

              context 'when last_synced_at is set', :freeze_time do
                using RSpec::Parameterized::TableSyntax

                where(:project_last_updated, :project_registry_last_synced, :expected) do
                  Time.current               | (Time.current - 1.minute)  | true
                  (Time.current - 2.minutes) | (Time.current - 1.minute)  | false
                  (Time.current - 3.minutes) | (Time.current - 1.minute)  | false
                  (Time.current - 3.minutes) | (Time.current - 5.minutes) | true
                end

                with_them do
                  before do
                    project.update!(last_repository_updated_at: project_last_updated)

                    create(:geo_project_repository_registry, :verification_succeeded,
                      project: project, last_synced_at: project_registry_last_synced)
                  end

                  it 'returns the expected value' do
                    message = expected ? 'out-of-date' : 'up-to-date'

                    expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(message: message))
                    expect(described_class.repository_out_of_date?(project.id)).to eq(expected)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
