# frozen_string_literal: true

module Analytics
  module AnalyticsSettingsHelper
    def product_analytics_configurator_connection_string_data(form_name:, value:, testid:)
      analytics_input_copy_visibility_data(
        "#{form_name}[product_analytics_configurator_connection_string]",
        value,
        'https://username:password@gl-configurator.gitlab.com',
        s_('ProductAnalytics|Snowplow configurator connection string'),
        s_('ProductAnalytics|The connection string for your Snowplow configurator instance.'),
        testid
      )
    end

    def cube_api_key_data(form_name:, value:, testid:)
      analytics_input_copy_visibility_data(
        "#{form_name}[cube_api_key]",
        value,
        nil,
        s_('ProductAnalytics|Cube API key'),
        s_('ProductAnalytics|Used to retrieve dashboard data from the Cube instance.'),
        testid
      )
    end

    private

    def analytics_input_copy_visibility_data(name, value, placeholder, label, description, testid)
      {
        name: name,
        value: value,
        form_input_group_props: {
          'data-testid': testid,
          placeholder: placeholder,
          id: name
        }.to_json,
        form_group_attributes: {
          label: label,
          label_for: name,
          description: description
        }.to_json
      }
    end
  end
end
