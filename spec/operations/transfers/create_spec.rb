require "rails_helper"

RSpec.describe Transfers::Create do
  let(:cash) { account!("cash", normal: "debit") }
  let!(:w1)  { account!("wallet_1_eur", holder: "wallet_1") }
  let!(:w2)  { account!("wallet_2_eur", holder: "wallet_2") }

  before do
    # fund wallet_1 with 100.00
    Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash, direction: "debit", amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 },
    ])
  end

  it "moves money between two holders' accounts" do
    described_class.call(from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR")
    expect(w1.balance).to eq(7_500)
    expect(w2.balance).to eq(2_500)
  end

  it "refuses to overdraw the source" do
    expect {
      described_class.call(from: "wallet_1", to: "wallet_2", amount: 99_999, currency: "EUR")
    }.to raise_error(Ledger::InsufficientFunds)
    expect(w1.balance).to eq(10_000)
  end

  it "replays idempotently" do
    described_class.call(from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR", idempotency_key: "t1")
    described_class.call(from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR", idempotency_key: "t1")
    expect(w2.balance).to eq(2_500) # applied once
  end

  it "raises when the holder has no account in that currency" do
    expect {
      described_class.call(from: "wallet_1", to: "wallet_2", amount: 100, currency: "USD")
    }.to raise_error(Ledger::AccountNotFound)
  end
end
