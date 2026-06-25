class CreateAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.string :external_id, null: false        # unique account handle, e.g. "wallet_1_eur"
      t.string :holder_ref, null: false         # the owner: groups one holder's per-currency accounts
      t.string :name, null: false
      t.string :currency, null: false, limit: 3 # ISO 4217 — ONE currency per account, always
      t.string :normal_balance, null: false     # 'debit' (assets) or 'credit' (liabilities/equity)
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :accounts, :external_id, unique: true
    # A holder gets at most one account per currency: "wallet_1" holds EUR and USD as two rows.
    add_index :accounts, [ :holder_ref, :currency ], unique: true
    add_check_constraint :accounts, "normal_balance IN ('debit','credit')", name: "accounts_normal_balance_valid"
    add_check_constraint :accounts, "currency ~ '^[A-Z]{3}$'", name: "accounts_currency_iso"
  end
end
