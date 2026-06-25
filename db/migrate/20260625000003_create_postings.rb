class CreatePostings < ActiveRecord::Migration[7.2]
  def change
    create_table :postings do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :direction, null: false          # 'debit' or 'credit'
      t.bigint :amount, null: false             # always positive, in minor units (cents)
      t.string :currency, null: false, limit: 3
      t.datetime :created_at, null: false       # no updated_at: postings are append-only
    end

    add_check_constraint :postings, "direction IN ('debit','credit')", name: "postings_direction_valid"
    add_check_constraint :postings, "amount > 0", name: "postings_amount_positive"

    # Signed contribution to the ledger: debit is +, credit is -.
    # A balanced journal entry has SUM(delta) = 0. Stored & generated so the app can never
    # disagree with the DB about an amount's sign.
    execute <<~SQL
      ALTER TABLE postings
        ADD COLUMN delta bigint
        GENERATED ALWAYS AS (CASE WHEN direction = 'debit' THEN amount ELSE -amount END) STORED;
    SQL

    add_index :postings, [:account_id, :id]     # fast balance scans / high-water-mark snapshots
  end
end
