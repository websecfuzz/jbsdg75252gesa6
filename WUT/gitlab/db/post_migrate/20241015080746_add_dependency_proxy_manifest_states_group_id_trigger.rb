# frozen_string_literal: true

class AddDependencyProxyManifestStatesGroupIdTrigger < Gitlab::Database::Migration[2.2]
  milestone '17.6'

  def up
    install_sharding_key_assignment_trigger(
      table: :dependency_proxy_manifest_states,
      sharding_key: :group_id,
      parent_table: :dependency_proxy_manifests,
      parent_sharding_key: :group_id,
      foreign_key: :dependency_proxy_manifest_id
    )
  end

  def down
    remove_sharding_key_assignment_trigger(
      table: :dependency_proxy_manifest_states,
      sharding_key: :group_id,
      parent_table: :dependency_proxy_manifests,
      parent_sharding_key: :group_id,
      foreign_key: :dependency_proxy_manifest_id
    )
  end
end
