module Transfers
  # POST /transfers — move `amount` of `currency` from one holder's account to another's.
  # Resolves each holder's account *in that currency* (one account = one currency), then
  # debits the source and credits the destination as a single balanced entry.
  class Create
    def self.call(...) = new(...).call

    def initialize(from:, to:, amount:, currency:, idempotency_key: nil, allow_overdraft: false)
      @from = from
      @to = to
      @amount = amount
      @currency = currency
      @idempotency_key = idempotency_key
      @allow_overdraft = allow_overdraft
    end

    def call
      source = resolve(@from)
      destination = resolve(@to)

      Ledger::PostEntry.call(
        description: "transfer #{@from} -> #{@to}",
        currency: @currency,
        idempotency_key: @idempotency_key,
        no_overdraft: @allow_overdraft ? [] : [source],
        lines: [
          { account: source,      direction: "debit",  amount: @amount },
          { account: destination, direction: "credit", amount: @amount },
        ]
      )
    end

    private

    def resolve(holder_ref)
      Account.find_by(holder_ref: holder_ref, currency: @currency) ||
        raise(Ledger::AccountNotFound, "no #{@currency} account for #{holder_ref}")
    end
  end
end
