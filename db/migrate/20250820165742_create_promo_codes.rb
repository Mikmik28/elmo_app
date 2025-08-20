class CreatePromoCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :promo_codes do |t|
      t.string :code, null: false
      t.string :promo_type
      t.decimal :discount_percentage, precision: 5, scale: 2
      t.decimal :discount_amount, precision: 10, scale: 2
      t.decimal :bonus_credit, precision: 10, scale: 2
      t.integer :usage_limit
      t.integer :used_count, default: 0
      t.date :valid_from
      t.date :valid_until
      t.boolean :active, default: true
      t.json :conditions
      t.timestamps
    end

    add_index :promo_codes, :code, unique: true
  end
end
