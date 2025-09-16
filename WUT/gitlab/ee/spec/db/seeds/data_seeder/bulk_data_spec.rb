# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../db/seeds/data_seeder/bulk_data'

# rubocop:disable RSpec/SpecFilePathFormat -- This is the current structure for this file
# rubocop:disable RSpec/FeatureCategory -- This was created in the context of a working group: https://handbook.gitlab.com/handbook/company/working-groups/demo-test-data/
# The better group to own this would be Engineering Productivity, but that group
# does not currently support any feature categories.
RSpec.describe DataSeeder, feature_category: :not_owned do
  it 'does not create records from the excluded factories', :aggregate_failures do
    # Creating them all takes time and this spec only cares about excluding some factories from the process,
    # so not calling original here
    allow(FactoryBot).to receive(:create)

    described_class::EXCLUDED_FACTORIES.map(&:to_sym).each do |factory_name|
      expect(FactoryBot).not_to receive(:create).with(factory_name)
    end

    described_class.new(true).seed
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
# rubocop:enable RSpec/FeatureCategory
