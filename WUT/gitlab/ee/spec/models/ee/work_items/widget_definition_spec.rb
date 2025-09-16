# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::WidgetDefinition, feature_category: :team_planning do
  describe '.available_widgets' do
    subject { described_class.available_widgets }

    it 'returns list of all possible widgets' do
      is_expected.to contain_exactly(
        ::WorkItems::Widgets::Description,
        ::WorkItems::Widgets::Hierarchy,
        ::WorkItems::Widgets::Iteration,
        ::WorkItems::Widgets::Labels,
        ::WorkItems::Widgets::Assignees,
        ::WorkItems::Widgets::Weight,
        ::WorkItems::Widgets::StartAndDueDate,
        ::WorkItems::Widgets::VerificationStatus,
        ::WorkItems::Widgets::HealthStatus,
        ::WorkItems::Widgets::Milestone,
        ::WorkItems::Widgets::Notes,
        ::WorkItems::Widgets::Progress,
        ::WorkItems::Widgets::RequirementLegacy,
        ::WorkItems::Widgets::TestReports,
        ::WorkItems::Widgets::Notifications,
        ::WorkItems::Widgets::CurrentUserTodos,
        ::WorkItems::Widgets::AwardEmoji,
        ::WorkItems::Widgets::LinkedItems,
        ::WorkItems::Widgets::Color,
        ::WorkItems::Widgets::Participants,
        ::WorkItems::Widgets::TimeTracking,
        ::WorkItems::Widgets::Designs,
        ::WorkItems::Widgets::Development,
        ::WorkItems::Widgets::CrmContacts,
        ::WorkItems::Widgets::EmailParticipants,
        ::WorkItems::Widgets::Status,
        ::WorkItems::Widgets::CustomFields,
        ::WorkItems::Widgets::ErrorTracking,
        ::WorkItems::Widgets::Vulnerabilities,
        ::WorkItems::Widgets::LinkedResources
      )
    end

    it 'has widget class for each widget type' do
      described_class.widget_types.each_key do |widget_name|
        widget_class_name = "WorkItems::Widgets::#{widget_name.camelcase}"
        expect(Object.const_defined?(widget_class_name)).to be true
      end

      expect(described_class.widget_types.size).to eq(described_class.available_widgets.size)
    end
  end

  describe 'data sync services' do
    it 'has corresponding data sync service' do
      described_class.widget_types.each_key do |widget_name|
        widget_class = "WorkItems::Widgets::#{widget_name.camelcase}".constantize

        expect(widget_class.sync_data_callback_class&.name).to eq(
          "WorkItems::DataSync::Widgets::#{widget_name.camelcase}"
        )
      end
    end
  end
end
