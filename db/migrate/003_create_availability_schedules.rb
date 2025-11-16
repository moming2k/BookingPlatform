class CreateAvailabilitySchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :availability_schedules do |t|
      t.references :service, null: false, foreign_key: true
      t.integer :day_of_week, null: false # 0-6 (Sunday-Saturday)
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.boolean :active, default: true
      t.date :valid_from
      t.date :valid_until
      t.jsonb :recurring_pattern, default: {} # For complex recurring patterns

      t.timestamps
    end

    add_index :availability_schedules, [:service_id, :day_of_week]
    add_index :availability_schedules, :active
    add_index :availability_schedules, [:valid_from, :valid_until]
  end
end