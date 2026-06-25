class CreateJournalEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :journal_entries do |t|
      t.string :description, null: false
      t.string :currency, null: false, limit: 3
      t.string :idempotency_key                 # unique per client request; null for non-API entries
      t.datetime :occurred_at, null: false      # business time (may differ from created_at)
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    # Idempotency: a repeated request with the same key must not create a second entry.
    add_index :journal_entries, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
    add_check_constraint :journal_entries, "currency ~ '^[A-Z]{3}$'", name: "journal_entries_currency_iso"
  end
end
