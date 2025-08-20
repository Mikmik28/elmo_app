class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :loan, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :payment_method
      t.string :payment_reference
      t.string :status, default: 'pending'
      t.json :payment_metadata
      t.datetime :paid_at
      t.timestamps
    end

    add_index :payments, [:loan_id, :status]
    add_index :payments, :payment_reference
  end
end
