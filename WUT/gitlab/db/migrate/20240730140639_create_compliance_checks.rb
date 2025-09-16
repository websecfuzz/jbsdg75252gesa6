# frozen_string_literal: true

class CreateComplianceChecks < Gitlab::Database::Migration[2.2]
  milestone '17.3'

  def change
    create_table :compliance_checks do |t| # rubocop:disable Migration/EnsureFactoryForTable -- https://gitlab.com/gitlab-org/gitlab/-/issues/468630
      t.timestamps_with_timezone null: false
      t.bigint :requirement_id, null: false
      t.bigint :namespace_id, null: false
      t.integer :check_name, null: false, limit: 2

      t.index :namespace_id
      t.index [:requirement_id, :check_name], unique: true, name: 'u_compliance_checks_for_requirement'
    end
  end
end
