class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :phone
      t.boolean :admin, default: false
      t.string :time_zone, default: "UTC"
      t.datetime :last_login_at
      t.string :magic_link_token
      t.datetime :magic_link_sent_at
      t.datetime :magic_link_confirmed_at
      t.string :stripe_customer_id
      t.jsonb :preferences, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :magic_link_token, unique: true
    add_index :users, :stripe_customer_id
    add_index :users, :deleted_at
  end
end