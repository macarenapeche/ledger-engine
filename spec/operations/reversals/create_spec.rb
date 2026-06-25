require "rails_helper"

RSpec.describe Reversals::Create do
  let(:cash) { account!("cash", normal: "debit") }
  let(:w1)   { account!("wallet_1_eur", holder: "wallet_1") }

  let(:original) do
    Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash, direction: "debit",  amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 }
    ])
  end

  it "posts the mirror: directions flipped, amounts unchanged" do
    reversal = described_class.call(original)
    expect(reversal.postings.map { [ _1.account_id, _1.direction, _1.amount ] }).to contain_exactly(
      [ cash.id, "credit", 10_000 ],
      [ w1.id,   "debit",  10_000 ],
    )
  end

  it "restores balances to where they were before the original" do
    original
    expect(w1.balance).to eq(10_000)
    described_class.call(original)
    expect(w1.balance).to eq(0)
    expect(cash.balance).to eq(0)
  end

  it "records the link back to the reversed entry" do
    reversal = described_class.call(original)
    expect(reversal.reverses_entry_id).to eq(original.id)
    expect(reversal).to be_reversal
  end

  it "is reverse-once: reversing twice returns the same reversal, no double-undo" do
    first  = described_class.call(original)
    second = described_class.call(original)
    expect(second.id).to eq(first.id)
    expect(w1.balance).to eq(0) # not +10_000 again
  end

  it "still posts when the reversal drives a balance negative" do
    original
    # spend everything out of w1 so reversing the funding must go negative
    w2 = account!("wallet_2_eur", holder: "wallet_2")
    Transfers::Create.call(from: "wallet_1", to: "wallet_2", amount: 10_000, currency: "EUR")
    expect(w1.balance).to eq(0)

    described_class.call(original)
    expect(w1.balance).to eq(-10_000) # correction always posts
  end

  it "refuses to reverse a reversal — chains are capped at one level" do
    reversal = described_class.call(original)
    expect { described_class.call(reversal) }.to raise_error(Ledger::IrreversibleEntry)
  end

  it "is not poisoned by a client idempotency key shaped like a reversal key" do
    # A transfer claiming the old-style "reversal-of-N" key must not be mistaken for the reversal.
    w2 = account!("wallet_2_eur", holder: "wallet_2")
    described_class # ensure original posted
    original
    Transfers::Create.call(from: "wallet_1", to: "wallet_2", amount: 1, currency: "EUR",
                           idempotency_key: "reversal-of-#{original.id}")

    reversal = described_class.call(original)
    expect(reversal.reverses_entry_id).to eq(original.id) # a real reversal, not the transfer
    expect(reversal).not_to eq(original)
  end

  it "lets you re-apply via a fresh entry instead of un-reversing" do
    described_class.call(original)
    expect(w1.balance).to eq(0)

    # re-apply the effect as a brand-new entry (which is itself reversible once)
    reapplied = Ledger::PostEntry.call(description: "re-fund", currency: "EUR", lines: [
      { account: cash, direction: "debit",  amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 }
    ])
    expect(w1.balance).to eq(10_000)
    expect { described_class.call(reapplied) }.not_to raise_error
  end
end
