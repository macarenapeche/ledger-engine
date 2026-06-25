class AddOriginatorToJournalEntries < ActiveRecord::Migration[7.2]
  def change
    # The root of a reversal chain: the original economic event a reversal (and any
    # reversal-of-reversal) ultimately traces back to. Null for originals themselves.
    add_reference :journal_entries, :originator, null: true,
      foreign_key: { to_table: :journal_entries }
  end
end
