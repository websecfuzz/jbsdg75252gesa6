# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item, class: 'Ai::Catalog::Item' do
    item_type { 1 }
    sequence(:name) { |n| "Item #{n}" }
    sequence(:description) { |n| "Item #{n}" }

    trait :with_version do
      versions { [association(:ai_catalog_item_version)] }
    end

    after(:build) do |item, _|
      item.organization ||=
        # The ordering of Organizations by created_at does not match ordering by the id column.
        # This is because Organization::DEFAULT_ORGANIZATION_ID is 1, but in the specs the default
        # organization may get created after another organization.
        Organizations::Organization.where(visibility_level: Gitlab::VisibilityLevel::PUBLIC).order(:created_at).first ||
        # We create an organization next even though we are building here. We need to ensure
        # that an organization exists so other entities can belong to the same organization
        build(:organization) # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- unable to create with association()
    end
  end
end
