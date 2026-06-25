class AddReversesEntryToJournalEntries < ActiveRecord::Migration[7.2]
  def change
    # Links a reversal entry to the entry it reverses. Null for ordinary entries.
    add_reference :journal_entries, :reverses_entry, null: true,
      foreign_key: { to_table: :journal_entries }

    # One reversal per original entry, enforced by the DB — this is the "reverse-once"
    # invariant, no longer riding on the shared idempotency_key column.
    add_index :journal_entries, :reverses_entry_id, unique: true,
      where: "reverses_entry_id IS NOT NULL", name: "index_journal_entries_one_reversal_per_entry"
  end
end
