# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AnalyticsSettingsHelper, feature_category: :product_analytics do
  let(:form_name) { 'project[foo_bar]' }
  let(:value) { 'some_value' }
  let(:testid) { 'some-testid' }

  describe '#product_analytics_configurator_connection_string_data' do
    let(:expected_name) { "#{form_name}[product_analytics_configurator_connection_string]" }

    it 'returns the expected data' do
      test_data = {
        placeholder: 'https://username:password@gl-configurator.gitlab.com',
        label: s_('ProductAnalytics|Snowplow configurator connection string'),
        description: s_('ProductAnalytics|The connection string for your Snowplow configurator instance.')
      }

      expect(helper.product_analytics_configurator_connection_string_data(form_name: form_name,
        value: value, testid: testid)).to eq(expected_data(test_data, expected_name))
    end
  end

  describe '#cube_api_key_data' do
    let(:expected_name) { "#{form_name}[cube_api_key]" }

    it 'returns the expected data' do
      test_data = {
        placeholder: nil,
        label: s_('ProductAnalytics|Cube API key'),
        description: s_('ProductAnalytics|Used to retrieve dashboard data from the Cube instance.')
      }

      expect(helper.cube_api_key_data(form_name: form_name,
        value: value, testid: testid)).to eq(expected_data(test_data, expected_name))
    end
  end

  def expected_data(test_data, expected_name)
    {
      name: expected_name,
      value: value,
      form_input_group_props: {
        'data-testid': testid,
        placeholder: test_data[:placeholder],
        id: expected_name
      }.to_json,
      form_group_attributes: {
        label: test_data[:label],
        label_for: expected_name,
        description: test_data[:description]
      }.to_json
    }
  end
end
