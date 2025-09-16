# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssuesSearch, :elastic_helpers, feature_category: :global_search do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:issue_epic_type) { create(:issue, :epic) }
  let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level) }
  let_it_be(:non_group_work_item) { create(:work_item, project: project) }
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    issue_epic_type.project = nil # Need to set this to nil as :epic feature is not enforing it.
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(false)
  end

  describe '#maintain_elasticsearch_update' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[non_group_work_item])
      non_group_work_item.maintain_elasticsearch_update
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue_epic_type])
      issue_epic_type.maintain_elasticsearch_update
    end

    it 'calls track! for work_item' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item])
      work_item.maintain_elasticsearch_update
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue])
      issue.maintain_elasticsearch_update
    end

    describe 'tracking embeddings' do
      let(:elasticsearch) { true }
      let(:opensearch) { false }

      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
        allow(helper).to receive(:matching_distribution?)
          .with(:elasticsearch, min_version: anything).and_return(elasticsearch)
        allow(helper).to receive(:matching_distribution?)
          .with(:opensearch, min_version: anything).and_return(opensearch)
      end

      context 'for project level work item' do
        subject(:record) { non_group_work_item }

        it 'tracks the embedding' do
          expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!).with(record)

          record.maintain_elasticsearch_update
        end

        context 'when the project is not public' do
          before do
            allow(project).to receive(:public?).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when a title or description is not updated' do
          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update(updated_attributes: ['id'])
          end
        end

        context 'when ai_global_switch feature flag is disabled' do
          before do
            stub_feature_flags(ai_global_switch: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when ai_vertex_embeddings feature is not available' do
          before do
            allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when elasticsearch_work_item_embedding feature flag is disabled' do
          before do
            stub_feature_flags(elasticsearch_work_item_embedding: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        describe 'vector support' do
          using RSpec::Parameterized::TableSyntax

          where(:elasticsearch, :opensearch, :vectors_supported) do
            true  | false | true
            false | true  | true
            false | false | false
          end

          with_them do
            it 'tracks embedding if vectors are supported' do
              if vectors_supported
                expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!).with(record)
              else
                expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)
              end

              record.maintain_elasticsearch_update
            end
          end
        end
      end

      it 'tracks the embedding for project level issue' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!)
          .with(WorkItem.find(issue.id))

        issue.maintain_elasticsearch_update
      end

      it 'does not track the embedding for group level issue' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        issue_epic_type.maintain_elasticsearch_update
      end

      it 'does not track the embedding for group level work item' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        work_item.maintain_elasticsearch_update
      end
    end
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[non_group_work_item])
      non_group_work_item.maintain_elasticsearch_create
    end

    it 'calls track! for work_item' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item])
      work_item.maintain_elasticsearch_create
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue_epic_type])
      issue_epic_type.maintain_elasticsearch_create
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue])
      issue.maintain_elasticsearch_create
    end

    describe 'tracking embeddings' do
      let(:elasticsearch) { true }
      let(:opensearch) { false }

      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
        allow(helper).to receive(:matching_distribution?)
          .with(:elasticsearch, min_version: anything).and_return(elasticsearch)
        allow(helper).to receive(:matching_distribution?)
          .with(:opensearch, min_version: anything).and_return(opensearch)
      end

      context 'for project level work item' do
        subject(:record) { non_group_work_item }

        it 'tracks the embedding' do
          expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!).with(record)

          record.maintain_elasticsearch_create
        end

        context 'when the project is not public' do
          before do
            allow(project).to receive(:public?).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when ai_global_switch feature flag is disabled' do
          before do
            stub_feature_flags(ai_global_switch: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when ai_vertex_embeddings feature is not available' do
          before do
            allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when elasticsearch_work_item_embedding feature flag is disabled' do
          before do
            stub_feature_flags(elasticsearch_work_item_embedding: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        describe 'vector support' do
          using RSpec::Parameterized::TableSyntax
          where(:elasticsearch, :opensearch, :vectors_supported) do
            true  | false | true
            false | false | false
            false | true  | true
          end

          with_them do
            it 'tracks embedding if vectors are supported' do
              if vectors_supported
                expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!).with(record)
              else
                expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)
              end

              record.maintain_elasticsearch_create
            end
          end
        end
      end

      it 'tracks the embedding for project level issue' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!)
          .with(WorkItem.find(issue.id))

        issue.maintain_elasticsearch_create
      end

      it 'does not track the embedding for group level issue' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        issue_epic_type.maintain_elasticsearch_create
      end

      it 'does not track the embedding for group level work item' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        work_item.maintain_elasticsearch_create
      end
    end
  end
end
