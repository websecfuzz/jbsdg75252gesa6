# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates scan execution policy", :js, feature_category: :security_policy_management do
  include ListboxHelpers

  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:path_to_policy_editor) { new_group_security_policy_path(group) }
  let_it_be(:policy_management_project) { create(:project, :repository, owners: owner) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_management_project,
      namespace: group
    )
  end

  before do
    sign_in(owner)
    stub_feature_flags(security_policies_split_view: false)
    stub_feature_flags(flexible_scan_execution_policy: false)
  end

  it_behaves_like 'creating scan execution policy with valid properties'

  it_behaves_like 'creating scan execution policy with invalid properties'
end
