# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::Dashboard, feature_category: :product_analytics do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) do
    create(:project, :repository,
      project_setting: build(:project_setting),
      group: group)
  end

  let_it_be(:config_project) do
    create(:project, :with_product_analytics_dashboard, group: group)
  end

  before_all do
    group.add_developer(user)
  end

  before do
    allow(Ability).to receive(:allowed?)
      .with(user, :read_enterprise_ai_analytics, anything)
      .and_return(true)
    allow(Ability).to receive(:allowed?)
      .with(user, :read_dora4_analytics, anything)
      .and_return(true)
    allow(Ability).to receive(:allowed?)
      .with(user, :read_project_merge_request_analytics, anything)
      .and_return(true)
    allow(Ability).to receive(:allowed?)
      .with(user, :read_duo_usage_analytics, anything)
      .and_return(true)

    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    stub_licensed_features(
      product_analytics: true,
      project_level_analytics_dashboard: true,
      group_level_analytics_dashboard: true,
      dora4_analytics: true,
      project_merge_request_analytics: true
    )
  end

  shared_examples 'returns the value streams dashboard' do
    it 'returns the value streams dashboard' do
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('Value Streams Dashboard')
      expect(dashboard.slug).to eq('value_streams_dashboard')
      expect(dashboard.description).to eq('Track key DevSecOps metrics throughout the development lifecycle.')
      expect(dashboard.filters).to be_nil
      expect(dashboard.schema_version).to eq('2')
    end
  end

  shared_examples 'returns the DORA Metrics dashboard' do
    it 'returns the value streams dashboard' do
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('DORA metrics analytics')
      expect(dashboard.slug).to eq('dora_metrics')
      expect(dashboard.description).to eq(
        "View current DORA metric performance and historical trends to analyze DevOps efficiency over time."
      )
    end

    it 'returns the correct panels' do
      expect(dashboard.panels.size).to eq(8)
    end
  end

  shared_examples 'returns the Merge request analytics dashboard' do
    it 'returns the merge request analytics dashboard' do
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('Merge request analytics')
      expect(dashboard.slug).to eq('merge_request_analytics')
      expect(dashboard.description).to eq(
        "MR stats and trends"
      )
    end

    it 'returns the correct panels' do
      expect(dashboard.panels.size).to eq(3)
    end
  end

  shared_examples 'returns the Duo usage dashboard' do
    it 'returns the Duo usage dashboard' do
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('GitLab Duo usage analytics')
      expect(dashboard.slug).to eq('duo_usage')
      expect(dashboard.description).to eq(
        "View detailed statistics of Duo usage over time."
      )
      expect(dashboard.status).to eq('experiment')
    end

    it 'returns the correct panels' do
      expect(dashboard.panels.size).to eq(1)
    end
  end

  describe '#errors' do
    let(:dashboard) do
      described_class.new(
        container: group,
        config: YAML.safe_load(config_yaml),
        slug: 'test2',
        user_defined: true,
        config_project: project
      )
    end

    context 'when yaml is valid' do
      let(:config_yaml) do
        File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read
      end

      it 'returns nil' do
        expect(dashboard.errors).to be_nil
      end
    end

    context 'when yaml is faulty' do
      let(:config_yaml) do
        <<-YAML
---
title: not good yaml
description: with missing properties
        YAML
      end

      it 'returns schema errors' do
        expect(dashboard.errors).to eq(["root is missing required keys: panels"])
      end
    end
  end

  describe '.for' do
    context 'when resource is a project' do
      let(:resource_parent) { project }

      subject(:dashboards) { described_class.for(container: resource_parent, user: user) }

      before do
        allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
        project.project_setting.update!(product_analytics_instrumentation_key: "key")
        allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
            'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
          }))
        end
      end

      it 'returns a collection of builtin dashboards' do
        expect(dashboards.map(&:title)).to match_array(
          [
            'Audience',
            'Behavior',
            'Value Streams Dashboard',
            'DORA metrics analytics',
            'AI impact analytics',
            'Merge request analytics',
            'GitLab Duo usage analytics'
          ]
        )
      end

      context 'when configuration project is set' do
        before do
          resource_parent.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns custom and builtin dashboards' do
          expect(dashboards).to be_a(Array)
          expect(dashboards.size).to eq(8)
          expect(dashboards.last).to be_a(described_class)
          expect(dashboards.last.title).to eq('Dashboard Example 1')
          expect(dashboards.last.slug).to eq('dashboard_example_1')
          expect(dashboards.last.description)
            .to eq('North Star Metrics across all departments for the last 3 quarters.')
          expect(dashboards.last.schema_version).to eq('2')
          expect(dashboards.last.filters).to eq({ "projects" => { "enabled" => true },
            "dateRange" => { "enabled" => true }, "excludeAnonymousUsers" => { "enabled" => true },
                                               "filteredSearch" => { "enabled" => true, "options" =>
                                                 [{ "token" => "label", "maxSuggestions" => 20 }] } })
          expect(dashboards.last.errors).to be_nil
        end
      end

      context 'when the dashboard file does not exist in the directory' do
        before do
          # Invalid dashboard - should not be included
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_1/project_dashboard_example_wrongly_named.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )

          # Valid dashboard - should be included
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_2/dashboard_example_2.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )
        end

        it 'excludes the dashboard from the list' do
          expected_dashboards =
            ["Audience", "Behavior", "Value Streams Dashboard", "AI impact analytics",
              "DORA metrics analytics", "Merge request analytics", "GitLab Duo usage analytics", "Dashboard Example 1"]

          expect(dashboards.map(&:title)).to eq(expected_dashboards)
        end
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'excludes product analytics dashboards' do
          expect(dashboards.size).to eq(6)
        end
      end
    end

    context 'when resource is a group' do
      let_it_be(:resource_parent) { group }

      subject(:dashboards) { described_class.for(container: resource_parent, user: user) }

      it 'returns a collection of builtin dashboards' do
        expect(dashboards.map(&:title)).to match_array(['Value Streams Dashboard', 'DORA metrics analytics',
          'AI impact analytics', 'GitLab Duo usage analytics', 'Contributions Dashboard'])
      end

      context 'when configuration project is set' do
        before do
          resource_parent.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns custom and builtin dashboards' do
          expect(dashboards).to be_a(Array)
          expect(dashboards.map(&:title)).to match_array(
            ['Value Streams Dashboard', 'AI impact analytics', 'DORA metrics analytics',
              'Dashboard Example 1', 'GitLab Duo usage analytics', 'Contributions Dashboard']
          )
        end
      end

      context 'when the dashboard file does not exist in the directory' do
        before do
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_1/group_dashboard_example_wrongly_named.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )
        end

        it 'excludes the dashboard from the list' do
          expect(dashboards.map(&:title)).to match_array(
            ['Value Streams Dashboard', 'AI impact analytics', 'DORA metrics analytics',
              'Dashboard Example 1', 'GitLab Duo usage analytics', 'Contributions Dashboard']
          )
        end
      end

      context 'when DORA metrics are not licensed' do
        before do
          allow(Ability).to receive(:allowed?)
                        .with(user, :read_enterprise_ai_analytics, anything)
                        .and_return(true)
          allow(Ability).to receive(:allowed?)
                        .with(user, :read_dora4_analytics, anything)
                        .and_return(false)
        end

        it 'excludes the dashboard from the list' do
          expect(dashboards.map(&:title)).not_to include('DORA metrics analytics')
        end
      end
    end

    context 'when resource is not a project or a group' do
      it 'raises error' do
        invalid_object = double

        error_message =
          "A group or project must be provided. Given object is RSpec::Mocks::Double type"
        expect { described_class.for(container: invalid_object, user: user) }
          .to raise_error(ArgumentError, error_message)
      end
    end
  end

  describe '#panels' do
    before do
      project.update!(analytics_dashboards_configuration_project: config_project, namespace: config_project.namespace)
    end

    subject(:panels) { described_class.for(container: project, user: user).last.panels }

    it { is_expected.to be_a(Array) }

    it 'is expected to contain two panels' do
      expect(panels.size).to eq(2)
    end

    it 'is expected to contain a panel with the correct title' do
      expect(panels.first.title).to eq('Overall Conversion Rate')
    end

    it 'is expected to contain a panel with the correct grid attributes' do
      expect(panels.first.grid_attributes).to eq({ 'xPos' => 1, 'yPos' => 4, 'width' => 12, 'height' => 2 })
    end

    it 'is expected to contain a panel with the correct query overrides' do
      expect(panels.first.query_overrides).to eq({
        'timeDimensions' => [{
          'dimension' => 'Stories.time',
          'dateRange' => %w[2016-01-01 2016-02-30],
          'granularity' => 'month'
        }]
      })
    end
  end

  describe '#==' do
    let(:dashboard_1) { described_class.for(container: project, user: user).first }
    let(:dashboard_2) do
      config_yaml =
        File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read
      config_yaml = YAML.safe_load(config_yaml)

      described_class.new(
        container: project,
        config: config_yaml,
        slug: 'test2',
        user_defined: true,
        config_project: project
      )
    end

    subject { dashboard_1 == dashboard_2 }

    it { is_expected.to be false }
  end

  describe '.value_stream_dashboard' do
    context 'for groups' do
      let(:dashboard) { described_class.value_stream_dashboard(group, config_project) }

      it_behaves_like 'returns the value streams dashboard'

      it 'returns the correct panels' do
        expect(dashboard.panels.size).to eq(6)
        expect(dashboard.panels.map { |panel| panel.visualization.type }).to eq(
          %w[UsageOverview DORAChart DORAChart DORAChart DoraPerformersScore DoraProjectsComparison]
        )
      end
    end

    context 'for projects' do
      let(:dashboard) { described_class.value_stream_dashboard(project, config_project) }

      it_behaves_like 'returns the value streams dashboard'

      it 'returns the correct panels' do
        expect(dashboard.panels.size).to eq(4)
        expect(dashboard.panels.map { |panel| panel.visualization.type }).to eq(
          %w[UsageOverview DORAChart DORAChart DORAChart]
        )
      end
    end
  end

  describe '.dora_metrics_dashboard' do
    context 'for groups' do
      let(:dashboard) { described_class.dora_metrics_dashboard(group, config_project) }

      it_behaves_like 'returns the DORA Metrics dashboard'
    end

    context 'for projects' do
      let(:dashboard) { described_class.dora_metrics_dashboard(project, config_project) }

      it_behaves_like 'returns the DORA Metrics dashboard'
    end
  end

  describe '.merge_request_analytics_dashboard' do
    context 'for groups' do
      subject { described_class.merge_request_analytics_dashboard(group, config_project, user) }

      it { is_expected.to be_nil }
    end

    context 'for projects' do
      let(:dashboard) { described_class.merge_request_analytics_dashboard(project, config_project, user) }

      it_behaves_like 'returns the Merge request analytics dashboard'
    end
  end

  describe '.ai_impact_dashboard' do
    context 'for groups' do
      subject(:dashboard) { described_class.ai_impact_dashboard(group, config_project, user) }

      it 'returns the dashboard' do
        expect(dashboard.title).to eq('AI impact analytics')
        expect(dashboard.slug).to eq('ai_impact')
        expect(dashboard.schema_version).to eq('2')
        expect(dashboard.filters).to be_nil
      end

      context 'when clickhouse is not enabled' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it { is_expected.to be_nil }
      end
    end

    context 'for projects' do
      subject(:dashboard) { described_class.ai_impact_dashboard(project, config_project, user) }

      it 'returns the dashboard' do
        expect(dashboard.title).to eq('AI impact analytics')
        expect(dashboard.slug).to eq('ai_impact')
        expect(dashboard.schema_version).to eq('2')
        expect(dashboard.filters).to be_nil
      end

      context 'when clickhouse is not enabled' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.contributions_dashboard' do
    context 'for groups' do
      subject(:dashboard) { described_class.contributions_dashboard(group, config_project) }

      it 'returns the dashboard' do
        expect(dashboard.title).to eq('Contributions Dashboard')
        expect(dashboard.slug).to eq('contributions_dashboard')
        expect(dashboard.schema_version).to eq('2')
        expect(dashboard.filters).to eq({ "dateRange" => { "enabled" => true, "numberOfDaysLimit" => 90,
                                                           "options" => %w[7d 30d 90d custom] } })
      end

      context 'when contributions_analytics_dashboard feature is disabled' do
        before do
          stub_feature_flags(contributions_analytics_dashboard: false)
        end

        it { is_expected.to be_nil }
      end
    end

    context 'for projects' do
      subject { described_class.contributions_dashboard(project, config_project) }

      it { is_expected.to be_nil }
    end
  end

  describe '.duo_usage_dashboard' do
    context 'for groups' do
      let(:dashboard) { described_class.duo_usage_dashboard(group, config_project, user) }

      it_behaves_like 'returns the Duo usage dashboard'

      context 'when read_duo_usage_analytics is not permitted' do
        before do
          allow(Ability).to receive(:allowed?)
                              .with(user, :read_duo_usage_analytics, anything)
                              .and_return(false)
        end

        it 'returns nil' do
          expect(dashboard).to be_nil
        end
      end
    end

    context 'for projects' do
      let(:dashboard) { described_class.duo_usage_dashboard(project, config_project, user) }

      it_behaves_like 'returns the Duo usage dashboard'

      context 'when read_duo_usage_analytics is not permitted' do
        before do
          allow(Ability).to receive(:allowed?)
                              .with(user, :read_duo_usage_analytics, anything)
                              .and_return(false)
        end

        it 'returns nil' do
          expect(dashboard).to be_nil
        end
      end
    end
  end

  describe '.load_yaml_dashboard_config' do
    let(:file_path) { '.gitlab/analytics/dashboards' }

    context 'when invalid path is provided' do
      it 'raises exception for absolute path traversal attempt' do
        invalid_file_name = '/tmp/foo'

        error_message = "path #{invalid_file_name} is not allowed"
        expect { described_class.load_yaml_dashboard_config(invalid_file_name, file_path) }
          .to raise_error(StandardError, error_message)
      end

      it 'raises exception when path traversal is attempted' do
        error_message = "Invalid path"
        expect { described_class.load_yaml_dashboard_config('../foo', file_path) }
          .to raise_error(Gitlab::PathTraversal::PathTraversalAttackError, error_message)
      end
    end

    context 'for valid path' do
      subject(:dashboard_config) do
        described_class.load_yaml_dashboard_config('behavior',
          'ee/lib/gitlab/analytics/product_analytics/dashboards')
      end

      it 'loads the dashboard config' do
        expect(dashboard_config["title"]).to eq('Behavior')
        expect(dashboard_config.size).to eq(5)
      end
    end
  end
end
