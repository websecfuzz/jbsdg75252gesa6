# frozen_string_literal: true

class InstanceSecurityDashboardPolicy < BasePolicy
  with_scope :global
  condition(:security_dashboard_enabled) do
    License.feature_available?(:security_dashboard)
  end

  # We grant permissions for selected resources because instance security dashboard is just a collection of projects.
  # We filter if user has access to projects in instance security dashboard when we are returning individual resources.
  # Instance Security Dashboard Policy cannot handle per role permissions, it is used to ensure that we can return
  # requested resources for a given user.

  rule { ~anonymous }.policy do
    enable :read_instance_security_dashboard
    enable :read_security_resource
  end

  rule { security_dashboard_enabled & can?(:read_instance_security_dashboard) }.policy do
    enable :create_vulnerability_export
    enable :read_cluster # Deprecated as certificate-based cluster integration (`Clusters::Cluster`).
    enable :read_cluster_agent
  end

  condition(:resolve_vulnerability_allowed) do
    ::Gitlab::Llm::FeatureAuthorizer.new(
      container: subject,
      feature_name: :resolve_vulnerability,
      user: @user
    ).allowed?
  end

  rule { can?(:read_security_resource) & resolve_vulnerability_allowed }.policy do
    enable :resolve_vulnerability_with_ai
  end
end
