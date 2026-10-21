# A claim is held by name, not by reference to a Name row: a name can be
# reserved without being in the list, and taking one out of the list does not
# take it away from the agent holding it.
class CreateClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :claims do |t|
      t.references :list, null: false, foreign_key: true
      t.string :name, null: false
      t.string :session   # nil: reserved by hand, and never lapses
      t.string :note
      t.string :host
      t.datetime :seen_at, null: false
      t.timestamps
    end
    # These two indexes are the whole of the collision guarantee: two agents
    # racing for one name, or one session racing itself, and the loser's
    # INSERT fails.
    add_index :claims, [ :list_id, :name ], unique: true
    add_index :claims, [ :list_id, :session ], unique: true
  end
end
