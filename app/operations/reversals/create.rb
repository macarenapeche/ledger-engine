module Reversals
  # Corrects a journal entry the only way an immutable ledger can: by posting its mirror.
  # Each leg's direction is flipped (debit <-> credit), amounts unchanged. Because the
  # original was balanced, the reversal is balanced too.
  #
  # Reverse-once: the idempotency key is derived from the original id, so reversing the same
  # entry twice returns the first reversal instead of posting a second one. A reversal entry
  # itself cannot be reversed, so chains are capped at one level (original -> reversal).
  class Create
    FLIP = { "debit" => "credit", "credit" => "debit" }.freeze

    def self.call(...) = new(...).call

    def initialize(original)
      @original = original
    end

    def call
      if original.metadata["reverses"].present?
        raise Ledger::IrreversibleEntry,
          "entry #{original.id} is itself a reversal (of #{original.metadata['reverses']}) and cannot be reversed"
      end

      Ledger::PostEntry.call(
        description: "reversal of entry #{original.id}",
        currency: original.currency,
        idempotency_key: "reversal-of-#{original.id}",
        no_overdraft: [], # a correction must always post, even if it drives a balance negative
        metadata: { "reverses" => original.id },
        lines: original.postings.map { |p|
          { account: p.account, direction: FLIP.fetch(p.direction), amount: p.amount }
        }
      )
    end

    private

    attr_reader :original
  end
end
