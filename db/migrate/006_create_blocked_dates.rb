class CreateBlockedDates < ActiveRecord::Migration[7.1]
  def change
    create_table :blocked_dates do |t|
      t.references :service, foreign_key: true # null means applies to all services
      t.date :blocked_date, null: false
      t.time :start_time # Optional: for partial day blocks
      t.time :end_time # Optional: for partial day blocks
      t.string :reason
      t.boolean :recurring_yearly, default: false

      t.timestamps
    end

    add_index :blocked_dates, [:service_id, :blocked_date]
    add_index :blocked_dates, :blocked_date
  end
end