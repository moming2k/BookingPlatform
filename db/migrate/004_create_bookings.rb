class CreateBookings < ActiveRecord::Migration[7.1]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :status, null: false, default: "pending" # pending, confirmed, cancelled, completed, no_show
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: "USD"
      t.string :booking_reference, null: false
      t.text :notes
      t.text :cancellation_reason
      t.datetime :cancelled_at
      t.references :cancelled_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.datetime :reminder_sent_at
      t.jsonb :metadata, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :bookings, :booking_reference, unique: true
    add_index :bookings, :status
    add_index :bookings, [:start_time, :end_time]
    add_index :bookings, [:service_id, :start_time]
    add_index :bookings, :deleted_at
  end
end