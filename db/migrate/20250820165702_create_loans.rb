class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :interest_rate, precision: 5, scale: 4, null: false
      t.decimal :total_amount_due, precision: 10, scale: 2, null: false
      t.integer :term_days, null: false
      t.date :due_date, null: false
      t.string :status, default: 'pending'
      t.string :purpose
      t.string :loan_type, default: 'personal'
      t.decimal :daily_penalty_rate, precision: 5, scale: 4, default: 0.005
      t.json :approval_metadata
      t.string :disbursement_method
      t.string :disbursement_account
      t.datetime :approved_at
      t.datetime :disbursed_at
      t.datetime :paid_at
      t.timestamps
    end

    add_index :loans, [:user_id, :status]
    add_index :loans, :status
    add_index :loans, :due_date
  end
end
