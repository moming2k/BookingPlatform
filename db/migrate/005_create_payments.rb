class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: "USD"
      t.string :status, null: false # pending, processing, succeeded, failed, refunded
      t.string :payment_method # card, bank_transfer, etc.
      t.string :stripe_payment_intent_id
      t.string :stripe_charge_id
      t.string :stripe_refund_id
      t.jsonb :stripe_response, default: {}
      t.text :failure_reason
      t.datetime :paid_at
      t.datetime :refunded_at
      t.decimal :refund_amount, precision: 10, scale: 2
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :payments, :status
    add_index :payments, :stripe_payment_intent_id
    add_index :payments, :stripe_charge_id
    add_index :payments, [:booking_id, :status]
  end
end