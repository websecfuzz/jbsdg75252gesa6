# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::Base, feature_category: :dependency_management do
  let(:pipeline) { instance_double('Ci::Pipeline') }
  let(:occurrence_maps) { [instance_double('Sbom::Ingestion::OccurrenceMap')] }

  describe '#each_pair' do
    context 'when implementation does not have unique_by columns in uses' do
      let(:implementation) do
        Class.new(described_class) do
          self.model = Sbom::ComponentVersion
          self.unique_by = %i[component_id version].freeze
          self.uses = %i[id].freeze

          def execute
            each_pair do |map, row|
              map.id = row.first
            end
          end
        end
      end

      it 'raises an ArgumentError' do
        expect { implementation.execute(pipeline, occurrence_maps) }.to raise_error(
          ArgumentError,
          'All unique_by attributes must be included in returned columns'
        )
      end
    end

    context 'when implementation does not have unique_by' do
      let(:implementation) do
        Class.new(described_class) do
          self.model = Sbom::ComponentVersion
          self.uses = %i[id].freeze

          def execute
            each_pair do |map, row|
              map.id = row.first
            end
          end
        end
      end

      it 'raises an ArgumentError' do
        expect { implementation.execute(pipeline, occurrence_maps) }.to raise_error(
          ArgumentError,
          '#each_pair can only be used with unique_by attributes'
        )
      end
    end
  end
end
