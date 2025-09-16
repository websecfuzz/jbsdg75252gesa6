# frozen_string_literal: true

class CreateNonSqlServicePing < Gitlab::Database::Migration[2.2]
  milestone '17.8'

  def change
    create_table :non_sql_service_pings do |t|
      t.timestamps_with_timezone null: false
      t.datetime_with_timezone :recorded_at, null: false
      t.jsonb :payload, null: false
      t.belongs_to :organization, null: false, foreign_key: { on_delete: :cascade }

      t.index [:recorded_at], unique: true
    end
  end
end
