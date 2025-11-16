class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.text :description
      t.integer :duration_minutes, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :currency, default: "USD"
      t.boolean :active, default: true
      t.integer :buffer_time_minutes, default: 0
      t.integer :max_advance_days, default: 60
      t.integer :min_advance_hours, default: 24
      t.jsonb :settings, default: {}
      t.string :slug
      t.string :color # For calendar display
      t.integer :position # For ordering
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :services, :slug, unique: true
    add_index :services, :active
    add_index :services, :position
    add_index :services, :deleted_at
  end
end