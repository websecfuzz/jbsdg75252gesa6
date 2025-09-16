# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_collection, class: 'Ai::ActiveContext::Collection' do
    sequence(:name) { |n| "Collection#{n}" }
    association :connection, factory: :ai_active_context_connection

    trait :code_embeddings_with_versions do
      name { 'gitlab_active_context_code' }
      collection_class { "Ai::ActiveContext::Collections::Code" }

      # the attributes for indexing_embedding_versions are defined in
      # Ai::ActiveContext::Collections::Code::MODEL
      indexing_embedding_versions { [1] }
    end
  end
end
