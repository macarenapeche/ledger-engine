module Reversals
  # Corrects a journal entry the only way an immutable ledger can: by posting its mirror.
  # Each leg's direction is flipped (debit <-> credit), amounts unchanged. Because the
  # original was balanced, the reversal is balanced too.
  #
  # Reverse-once is structural, via the reverses_entry link: a unique index enforces one
  # reversal per original entry at the DB level (not a magic idempotency key sharing a
  # namespace with client requests). A reversal is itself a normal, linked entry, so it can
  # be reversed in turn — that forms an auditable chain (X -> R1 -> R2 ...), each entry still
  # reverse-once, no cycles.
  class Create
    FLIP = { "debit" => "credit", "credit" => "debit" }.freeze

    def self.call(...) = new(...).call

    def initialize(original)
      @original = original
    end

    def call
      existing = original.reversal
      return existing if existing

      Ledger::PostEntry.call(
        description: "reversal of entry #{original.id}",
        currency: original.currency,
        reverses_entry: original,
        no_overdraft: [], # a correction must always post, even if it drives a balance negative
        lines: original.postings.map { |p|
          { account: p.account, direction: FLIP.fetch(p.direction), amount: p.amount }
        }
      )
    rescue ActiveRecord::RecordNotUnique
      # Lost the reverse-once race: another request just created the reversal. Return it.
      original.reload.reversal or raise
    end

    private

    attr_reader :original
  end
end
