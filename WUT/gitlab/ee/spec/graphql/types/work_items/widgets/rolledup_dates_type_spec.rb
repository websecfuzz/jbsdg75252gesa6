# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::Widgets::RolledupDatesType, feature_category: :team_planning do
  it { expect(described_class.graphql_name).to eq('WorkItemWidgetRolledupDates') }
end
