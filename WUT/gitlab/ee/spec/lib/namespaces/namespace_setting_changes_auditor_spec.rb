# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::NamespaceSettingChangesAuditor, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:destination) { create(:external_audit_event_destination, group: group) }

    subject(:auditor) { described_class.new(user, group.namespace_settings, group) }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
      group.external_audit_event_destinations.create!(destination_url: 'http://example.com')
    end

    shared_examples 'audited setting' do
      before do
        group.namespace_settings.update!(column_name => prev_value)
      end

      it 'creates an audit event' do
        group.namespace_settings.update!(column_name => new_value)

        expect { auditor.execute }.to change { AuditEvent.count }.by(1)
        audit_details = {
          change: column_name,
          from: prev_value,
          to: new_value,
          target_details: group.full_path
        }
        expect(AuditEvent.last.details).to include(audit_details)
      end

      it 'streams correct audit event stream' do
        group.namespace_settings.update!(column_name => new_value)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          described_class::EVENT_NAME_PER_COLUMN[column_name], anything, anything)

        auditor.execute
      end

      context 'when attribute is not changed' do
        it 'does not create an audit event' do
          group.namespace_settings.update!(column_name => prev_value)

          expect { auditor.execute }.not_to change { AuditEvent.count }
        end
      end
    end

    context 'for all columns' do
      where(:column_name, :prev_value, :new_value) do
        :duo_features_enabled | true | false
        :experiment_features_enabled | false | true
        :prevent_forking_outside_group | false | true
        :allow_mfa_for_subgroups | false | true
        :default_branch_name | "branch1" | "branch2"
        :resource_access_token_creation_allowed | true | false
        :show_diff_preview_in_email | false | true
        :enabled_git_access_protocol | "all" | "ssh"
        :runner_registration_enabled | false | true
        :allow_runner_registration_token | false | true
        :emails_enabled | false | true
        :service_access_tokens_expiration_enforced | false | true
        :enforce_ssh_certificates | false | true
        :disable_personal_access_tokens | false | true
        :remove_dormant_members | false | true
        :remove_dormant_members_period | 90 | 100
        :prevent_sharing_groups_outside_hierarchy | false | true
      end

      with_them do
        context 'when settings are changed for saas', :saas do
          let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, trial_ends_on: Date.tomorrow) }
          let_it_be(:destination) { create(:external_audit_event_destination, group: group) }

          before do
            stub_licensed_features(
              ai_features: true,
              experimental_features: true,
              extended_audit_events: true,
              external_audit_events: true)
            stub_ee_application_setting(should_check_namespace_plan: true)
          end

          it_behaves_like 'audited setting'
        end

        context 'when settings are changed for self-managed' do
          it_behaves_like 'audited setting'
        end
      end
    end

    context 'when attribute is new_user_signup_cap' do
      let(:prev_value) { 0 }
      let(:new_value) { 1 }
      let(:column_name) { :new_user_signups_cap }

      before do
        allow(group).to receive(:user_cap_available?).and_return true
        group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: 0)
      end

      it_behaves_like 'audited setting'
    end

    it 'audits all the columns except the ones denylisted' do
      columns_not_to_audit = %w[created_at updated_at namespace_id repository_read_only last_dormant_member_review_at
        setup_for_company jobs_to_be_done runner_token_expiration_interval
        subgroup_runner_token_expiration_interval project_runner_token_expiration_interval product_analytics_enabled
        unique_project_download_limit unique_project_download_limit_interval_in_seconds math_rendering_limits_enabled
        unique_project_download_limit_allowlist early_access_program_joined_by_id default_branch_protection_defaults
        allow_merge_on_skipped_pipeline default_compliance_framework_id unique_project_download_limit_alertlist
        only_allow_merge_if_all_discussions_are_resolved enterprise_users_extensions_marketplace_opt_in_status
        default_branch_protection_defaults allow_merge_without_pipeline auto_ban_user_on_excessive_projects_download
        lock_math_rendering_limits_enabled enable_auto_assign_gitlab_duo_pro_seats early_access_program_participant
        lock_duo_features_enabled allow_merge_without_pipeline only_allow_merge_if_pipeline_succeeds
        lock_spp_repository_pipeline_access spp_repository_pipeline_access archived
        resource_access_token_notify_inherited lock_resource_access_token_notify_inherited
        pipeline_variables_default_role extended_grat_expiry_webhooks_execute force_pages_access_control
        jwt_ci_cd_job_token_enabled jwt_ci_cd_job_token_opted_out require_dpop_for_manage_api_endpoints
        disable_invite_members job_token_policies_enabled security_policies duo_nano_features_enabled
        lock_model_prompt_cache_enabled model_prompt_cache_enabled lock_web_based_commit_signing_enabled
        web_based_commit_signing_enabled allow_enterprise_bypass_placeholder_confirmation enterprise_bypass_expires_at]

      columns_to_audit = Namespaces::NamespaceSettingChangesAuditor::EVENT_NAME_PER_COLUMN.keys.map(&:to_s)

      expect(NamespaceSetting.columns.map(&:name) - columns_not_to_audit).to match_array(columns_to_audit)
    end
  end
end
