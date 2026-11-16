class CreateInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :insights do |t|
      t.references :study_record, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :body, null: false, limit: 100

      t.timestamps
    end

    add_index :insights, [ :study_record_id, :kind ], unique: true

    add_check_constraint :insights,
                         "kind IN ('went_well', 'to_improve')",
                         name: "insights_kind_allowed_values"
  end
end
