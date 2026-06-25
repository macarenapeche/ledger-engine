class CreateBalanceSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :balance_snapshots do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :balance, null: false            # in the account's normal-balance orientation
      t.bigint :last_posting_id, null: false    # high-water mark: includes all postings with id <= this
      t.bigint :postings_count, null: false
      t.datetime :captured_at, null: false
      t.timestamps
    end

    # One snapshot per (account, high-water mark): re-running capture is idempotent.
    add_index :balance_snapshots, [ :account_id, :last_posting_id ], unique: true
  end
end
