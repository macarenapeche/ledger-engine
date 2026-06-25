require "rails_helper"

RSpec.describe Ledger::PostEntry do
  let(:cash)   { account!("cash", normal: "debit") }
  let(:wallet) { account!("wallet", normal: "credit") }

  def fund(amount, key: nil)
    described_class.call(
      description: "fund", currency: "EUR", idempotency_key: key,
      lines: [
        { account: cash,   direction: "debit",  amount: },
        { account: wallet, direction: "credit", amount: }
      ]
    )
  end

  it "posts a balanced entry and moves both balances" do
    fund(10_000)
    expect(cash.balance).to eq(10_000)    # asset up
    expect(wallet.balance).to eq(10_000)  # liability up
  end

  it "rejects an unbalanced entry before touching the DB" do
    expect {
      described_class.call(description: "bad", currency: "EUR", lines: [
        { account: cash,   direction: "debit",  amount: 100 },
        { account: wallet, direction: "credit", amount: 50 }
      ])
    }.to raise_error(Ledger::UnbalancedEntry)
  end

  it "rejects postings in a currency other than the entry's" do
    usd = account!("wallet_usd", holder: "x", currency: "USD")
    expect {
      described_class.call(description: "bad", currency: "EUR", lines: [
        { account: cash, direction: "debit", amount: 100 },
        { account: usd,  direction: "credit", amount: 100 }
      ])
    }.to raise_error(Ledger::CurrencyMismatch)
  end

  it "is idempotent: the same key returns the original entry, no double-post" do
    first  = fund(10_000, key: "req_1")
    second = fund(10_000, key: "req_1")
    expect(second.id).to eq(first.id)
    expect(wallet.balance).to eq(10_000) # not 20_000
  end

  # Proof the guarantee lives in the DB, not just the app: bypass PostEntry, write an
  # unbalanced entry straight through ActiveRecord, force the deferred check — Postgres rejects it.
  it "the database itself refuses an unbalanced entry at constraint-check time" do
    expect {
      ActiveRecord::Base.transaction do
        entry = JournalEntry.create!(description: "raw", currency: "EUR", occurred_at: Time.current)
        Posting.create!(journal_entry: entry, account: cash,   direction: "debit",  amount: 100, currency: "EUR")
        Posting.create!(journal_entry: entry, account: wallet, direction: "credit", amount: 99,  currency: "EUR")
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
      end
    }.to raise_error(ActiveRecord::StatementInvalid, /unbalanced/)
  end
end
