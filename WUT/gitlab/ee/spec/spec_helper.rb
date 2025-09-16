# frozen_string_literal: true

require Rails.root.join("spec/support/helpers/stub_requests.rb")

Dir[Rails.root.join("ee/spec/support/helpers/*.rb")].each { |f| require f }
Dir[Rails.root.join("ee/spec/support/shared_contexts/*.rb")].each { |f| require f }
Dir[Rails.root.join("ee/spec/support/shared_examples/*.rb")].each { |f| require f }
Dir[Rails.root.join("ee/spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include EE::LicenseHelpers

  include StubSaasFeatures

  config.define_derived_metadata(file_path: %r{ee/spec/}) do |metadata|
    # For now, we assign a starter license for ee/spec
    metadata[:with_license] = metadata.fetch(:with_license, true)

    location = metadata[:location]
    metadata[:geo] = metadata.fetch(:geo, true) if %r{[/_]geo[/_]}.match?(location)
  end

  config.define_derived_metadata do |metadata|
    # There's already a value, so do not set a default
    next if metadata.has_key?(:without_license)
    # There's already an opposing value, so do not set a default
    next if metadata.has_key?(:with_license)

    metadata[:without_license] = true
  end

  config.before(:context, :with_license) do
    License.destroy_all # rubocop: disable Cop/DestroyAll
    TestLicense.init
  end

  config.after(:context, :with_license) do
    License.destroy_all # rubocop: disable Cop/DestroyAll
  end

  config.before(:context, :without_license) do
    License.destroy_all # rubocop: disable Cop/DestroyAll
  end

  config.after(:context, :without_license) do
    TestLicense.init
  end

  config.around(:example, :with_cloud_connector) do |example|
    cloud_connector_access = create(:cloud_connector_access)

    example.run
  ensure
    cloud_connector_access.destroy!
  end

  config.around(:each, :geo_tracking_db) do |example|
    example.run if Gitlab::Geo.geo_database_configured?
  end

  config.define_derived_metadata do |metadata|
    metadata[:do_not_stub_snowplow_by_default] = true if metadata.has_key?(:snowplow_micro)
  end

  config.before(:example, :snowplow_micro) do
    config.include(Matchers::Snowplow)

    next unless Gitlab::Tracking.micro_verification_enabled?

    Matchers::Snowplow.clean_snowplow_queue

    stub_application_setting(snowplow_enabled: true)
    stub_application_setting(snowplow_app_id: 'gitlab-test')
  end

  config.include SecretsManagement::GitlabSecretsManagerHelpers, :gitlab_secrets_manager

  config.before do |example|
    if example.metadata.fetch(:stub_feature_flags, true)
      # This feature flag toggles the UI for Secrets Manager and is disabled by default.
      # It requires setting up openbao with gdk. Openbao integration and MVC development are still in progress.
      # We are running a temporary experiment where the Secrets Manager UI is located in the CI/CD settings for now
      # (which affects tests within that page) but it will eventually be moved to its own page for the MVC.
      # See https://gitlab.com/groups/gitlab-org/-/epics/14243.
      stub_feature_flags(ci_tanukey_ui: false)

      # Model/Table extraction will span multiple MRs and milestones, will remove this when we're
      # close to finished. See https://gitlab.com/groups/gitlab-org/-/epics/17390 for refactor plan.
      stub_feature_flags(extract_admin_roles_from_member_roles: false)
    end
  end

  config.before(:example, :gitlab_secrets_manager) do
    private_key_path = Rails.root.join('ee/spec/fixtures/secrets_manager/test_private_key.pem')
    private_key = File.read(private_key_path)

    public_key_path = Rails.root.join('ee/spec/fixtures/secrets_manager/test_public_key.pem')
    public_key = File.read(public_key_path)
    stub_application_setting(ci_jwt_signing_key: private_key.to_s)

    SecretsManagement::OpenbaoTestSetup.start_server
    SecretsManagement::OpenbaoTestSetup.configure_jwt_auth(public_key.to_s)
  end

  config.after(:example, :gitlab_secrets_manager) do
    # For now we'll just clean up kv secrets engines because that's
    # all we're handling in the secrets manager for now. We can add more
    # things to clean up here later on as we add more features.
    clean_all_kv_secrets_engines
    clean_all_pipeline_jwt_engines
    clean_all_policies
  end
end
