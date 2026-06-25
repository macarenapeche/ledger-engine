module Ledger
  # The one primitive every money movement goes through. Writes a balanced journal entry
  # and its postings atomically. Everything else (transfers, fees, reversals) is just a
  # different set of `lines`.
  #
  #   Ledger::PostEntry.call(
  #     description: "transfer",
  #     currency: "EUR",
  #     idempotency_key: "req_123",
  #     lines: [
  #       { account: src, direction: "debit",  amount: 100 },
  #       { account: dst, direction: "credit", amount: 100 },
  #     ],
  #     no_overdraft: [src],   # accounts that may not go negative
  #   )
  class PostEntry
    Line = Struct.new(:account, :direction, :amount, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(description:, currency:, lines:, idempotency_key: nil, no_overdraft: [], occurred_at: nil, metadata: {})
      @description = description
      @currency = currency
      @idempotency_key = idempotency_key
      @lines = lines.map { |l| Line.new(**l) }
      @no_overdraft = no_overdraft
      @occurred_at = occurred_at || Time.current
      @metadata = metadata
    end

    def call
      validate_balanced!
      replay = existing_by_idempotency_key and return replay

      ActiveRecord::Base.transaction do
        lock_accounts!
        guard_overdrafts!
        write_entry!
      end
    rescue ActiveRecord::RecordNotUnique
      # Lost an idempotency-key race: the winner already committed. Return their entry.
      existing_by_idempotency_key or raise
    end

    private

      attr_reader :description, :currency, :idempotency_key, :lines, :no_overdraft, :occurred_at, :metadata

      def validate_balanced!
        debits  = lines.select { _1.direction == "debit" }.sum(&:amount)
        credits = lines.select { _1.direction == "credit" }.sum(&:amount)
        raise UnbalancedEntry, "debits (#{debits}) != credits (#{credits})" unless debits == credits
        raise UnbalancedEntry, "need at least 2 postings" if lines.size < 2

        mismatched = lines.map { _1.account.currency }.uniq - [ currency ]
        raise CurrencyMismatch, "all postings must be in #{currency}" unless mismatched.empty?
      end

      def existing_by_idempotency_key
        idempotency_key && JournalEntry.find_by(idempotency_key:)
      end

      # Lock involved accounts in a stable order (by id) so concurrent transfers can't deadlock.
      def lock_accounts!
        Account.where(id: lines.map { _1.account.id }).order(:id).lock.load
      end

      def guard_overdrafts!
        no_overdraft.each do |account|
          debited = lines.select { _1.account.id == account.id }.sum { _1.direction == "debit" ? _1.amount : -_1.amount }
          # debiting a credit-normal (liability) account lowers its balance
          projected = account.balance - (account.normal_balance == "credit" ? debited : -debited)
          raise InsufficientFunds, "#{account.external_id} would go negative (#{projected})" if projected.negative?
        end
      end

      def write_entry!
        entry = JournalEntry.create!(
          description:, currency:,
          idempotency_key:, occurred_at:, metadata:
        )
        lines.each do |l|
          entry.postings.create!(account: l.account, direction: l.direction, amount: l.amount, currency:)
        end
        entry
      end
  end
end
