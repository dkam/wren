class CreateLists < ActiveRecord::Migration[8.1]
  def change
    create_table :lists do |t|
      t.string :token, null: false
      t.string :title
      t.timestamps
    end
    add_index :lists, :token, unique: true
  end
end
