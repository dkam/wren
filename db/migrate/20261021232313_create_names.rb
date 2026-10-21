class CreateNames < ActiveRecord::Migration[8.1]
  def change
    create_table :names do |t|
      t.references :list, null: false, foreign_key: true
      t.string :value, null: false
      t.timestamps
    end
    add_index :names, [ :list_id, :value ], unique: true
  end
end
