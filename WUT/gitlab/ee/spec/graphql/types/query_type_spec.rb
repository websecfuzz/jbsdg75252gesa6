# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Query'], feature_category: :shared do
  include_context 'with FOSS query type fields'

  specify do
    expected_ee_fields = [
      :add_on_purchases,
      :ai_catalog_item,
      :ai_catalog_items,
      :ai_messages,
      :ai_conversation_threads,
      :ai_chat_context_presets,
      :blob_search,
      :ci_catalog_resources,
      :ci_catalog_resource,
      :ci_minutes_usage,
      :ci_dedicated_hosted_runner_filters,
      :ci_dedicated_hosted_runner_usage,
      :ci_queueing_history,
      :configured_ai_catalog_items,
      :current_license,
      :devops_adoption_enabled_namespaces,
      :duo_workflow_events,
      :duo_workflow_workflows,
      :epic_board_list,
      :geo_node,
      :instance_security_dashboard,
      :iteration,
      :license_history_entries,
      :member_role_permissions,
      :admin_member_role_permissions,
      :ml_model,
      :ml_experiment,
      :organization,
      :runner_usage_by_project,
      :runner_usage,
      :subscription_future_entries,
      :vulnerabilities,
      :vulnerabilities_count_by_day,
      :vulnerability,
      :workspace,
      :workspaces,
      :instance_external_audit_event_destinations,
      :instance_google_cloud_logging_configurations,
      :audit_events_instance_amazon_s3_configurations,
      :member_role,
      :member_roles,
      :admin_member_role,
      :admin_member_roles,
      :self_managed_add_on_eligible_users,
      :standard_role,
      :standard_roles,
      :google_cloud_artifact_registry_repository_artifact,
      :audit_events_instance_streaming_destinations,
      :self_managed_users_queued_for_role_promotion,
      :ai_self_hosted_models,
      :cloud_connector_status,
      :project_secrets_manager,
      :project_secrets,
      :secret_permissions,
      :project_secret,
      :ai_feature_settings,
      :ai_slash_commands,
      :compliance_requirement_controls,
      :duo_settings,
      :custom_field,
      :ldap_admin_role_links,
      :ai_model_selection_namespace_settings,
      :dependency,
      :project_compliance_violation
    ]

    all_expected_fields = expected_foss_fields + expected_ee_fields

    expect(described_class).to have_graphql_fields(*all_expected_fields)
  end

  describe 'epicBoardList field' do
    subject { described_class.fields['epicBoardList'] }

    it 'finds an epic board list by its gid' do
      is_expected.to have_graphql_arguments(:id, :epic_filters)
      is_expected.to have_graphql_type(Types::Boards::EpicListType)
      is_expected.to have_graphql_resolver(Resolvers::Boards::EpicListResolver)
    end
  end

  describe '.authorization_scopes' do
    it 'includes :ai_workflows' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'field scopes' do
    {
      'vulnerabilities' => %i[api read_api ai_workflows],
      'vulnerability' => %i[api read_api ai_workflows]
    }.each do |field, scopes|
      it "includes the correct scopes for #{field}" do
        expect(described_class.fields[field].instance_variable_get(:@scopes)).to include(*scopes)
      end
    end
  end
end
