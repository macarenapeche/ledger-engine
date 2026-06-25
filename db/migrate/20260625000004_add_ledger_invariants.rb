class AddLedgerInvariants < ActiveRecord::Migration[7.2]
  # The invariants that make this a *ledger* and not just three tables, enforced in the DB
  # so they hold even against raw SQL, a buggy service, or a concurrent writer.
  def up
    # 1. Double-entry balance check, DEFERRED to commit so a transaction can insert both legs
    #    of an entry before the check runs. At COMMIT every touched entry must:
    #      - have >= 2 postings
    #      - use a single currency
    #      - have debits == credits  (SUM(delta) = 0)
    execute <<~SQL
      CREATE FUNCTION assert_journal_entry_balanced() RETURNS trigger AS $$
      DECLARE
        total bigint;
        cnt int;
        currencies int;
      BEGIN
        SELECT COALESCE(SUM(delta), 0), COUNT(*), COUNT(DISTINCT currency)
          INTO total, cnt, currencies
          FROM postings
          WHERE journal_entry_id = NEW.journal_entry_id;

        IF cnt < 2 THEN
          RAISE EXCEPTION 'journal entry % must have at least 2 postings (has %)', NEW.journal_entry_id, cnt;
        END IF;
        IF currencies <> 1 THEN
          RAISE EXCEPTION 'journal entry % mixes currencies', NEW.journal_entry_id;
        END IF;
        IF total <> 0 THEN
          RAISE EXCEPTION 'journal entry % is unbalanced: debits - credits = %', NEW.journal_entry_id, total;
        END IF;
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;

      CREATE CONSTRAINT TRIGGER postings_balance_check
        AFTER INSERT ON postings
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION assert_journal_entry_balanced();
    SQL

    # 2. Append-only audit trail: corrections happen via reversing entries, never by editing
    #    history. Block UPDATE/DELETE on the immutable tables at the DB level.
    execute <<~SQL
      CREATE FUNCTION forbid_mutation() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION '% on % is forbidden: the ledger is append-only', TG_OP, TG_TABLE_NAME;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER postings_immutable
        BEFORE UPDATE OR DELETE ON postings
        FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

      CREATE TRIGGER journal_entries_immutable
        BEFORE UPDATE OR DELETE ON journal_entries
        FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS postings_balance_check ON postings;
      DROP TRIGGER IF EXISTS postings_immutable ON postings;
      DROP TRIGGER IF EXISTS journal_entries_immutable ON journal_entries;
      DROP FUNCTION IF EXISTS assert_journal_entry_balanced();
      DROP FUNCTION IF EXISTS forbid_mutation();
    SQL
  end
end
