# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_security_testing custom role', feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:group) { project.group }
  let_it_be(:user) { create(:user) }

  let_it_be(:role) { create(:member_role, :guest, :admin_security_testing, namespace: group) }
  let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

  before do
    stub_licensed_features(
      custom_roles: true,
      security_dashboard: true,
      security_on_demand_scans: true,
      security_scans_api: true,
      secret_push_protection: true,
      container_scanning_for_registry: true,
      coverage_fuzzing: true)
    stub_feature_flags(custom_ability_admin_security_testing: true)
    sign_in(user)
  end

  describe "Controllers endpoints" do
    describe Projects::Security::ApiFuzzingConfigurationController do
      it 'can access the show endpoint' do
        get project_security_configuration_api_fuzzing_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::DastConfigurationController do
      it 'can access the show endpoint' do
        get project_security_configuration_dast_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::SecretDetectionConfigurationController do
      it 'can access the show endpoint' do
        get project_security_configuration_secret_detection_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::SastConfigurationController do
      it 'can access the show endpoint' do
        get project_security_configuration_sast_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::CorpusManagementController do
      it 'can access the show endpoint' do
        get project_security_configuration_corpus_management_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::DastProfilesController do
      it 'can access the show endpoint' do
        get project_security_configuration_profile_library_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::DastScannerProfilesController do
      it 'can access the show endpoint' do
        get new_project_security_configuration_profile_library_dast_scanner_profile_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe Projects::Security::DastSiteProfilesController do
      it 'can access the show endpoint' do
        get new_project_security_configuration_profile_library_dast_site_profile_path(project)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'GraphQL mutations' do
    include GraphqlHelpers

    let(:full_path) { project.full_path }

    let(:fields) do
      <<~FIELDS
        errors
      FIELDS
    end

    let(:mutation_name) { nil }
    let(:mutation) { graphql_mutation(mutation_name, input, fields) }

    subject(:execute_mutation) { post_graphql_mutation(mutation, current_user: user) }

    describe Mutations::Security::CiConfiguration::ConfigureContainerScanning do
      let(:mutation_name) { :configureContainerScanning }
      let(:input) { { project_path: full_path } }

      it 'has access via a custom role' do
        execute_mutation
        expect_graphql_errors_to_be_empty
      end
    end

    describe Mutations::Security::CiConfiguration::ConfigureDependencyScanning do
      let(:mutation_name) { :configureDependencyScanning }
      let(:input) { { project_path: full_path } }

      it 'has access via a custom role' do
        execute_mutation
        expect_graphql_errors_to_be_empty
      end
    end

    describe Mutations::Security::CiConfiguration::SetContainerScanningForRegistry do
      let(:mutation_name) { :setContainerScanningForRegistry }
      let(:input) { { namespace_path: full_path, enable: true } }

      it 'has access via a custom role' do
        execute_mutation
        expect_graphql_errors_to_be_empty
      end
    end

    describe Mutations::Security::CiConfiguration::SetGroupSecretPushProtection do
      let(:mutation_name) { :setGroupSecretPushProtection }
      let(:input) { { namespace_path: group.full_path, secret_push_protection_enabled: true } }

      it 'has access via a custom role' do
        execute_mutation
        expect_graphql_errors_to_be_empty
      end
    end

    describe Mutations::Security::CiConfiguration::SetPreReceiveSecretDetection do
      let(:mutation_name) { :setPreReceiveSecretDetection }
      let(:input) { { namespace_path: full_path, enable: true } }

      it 'has access via a custom role' do
        execute_mutation
        expect_graphql_errors_to_be_empty
      end
    end
  end
end
