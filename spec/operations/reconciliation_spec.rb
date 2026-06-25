require "rails_helper"

RSpec.describe Reconciliation do
  let(:cash) { account!("cash", normal: "debit") }
  let!(:w1)  { account!("wallet_1_eur", holder: "wallet_1") }
  let!(:w2)  { account!("wallet_2_eur", holder: "wallet_2") }

  it "trial balance is zero per currency in a closed ledger" do
    Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash, direction: "debit", amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 },
    ])
    Transfers::Create.call(from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR")

    expect(described_class.trial_balance).to eq("EUR" => 0)
    expect(described_class).to be_balanced
  end

  it "a snapshot reconciles against later postings" do
    Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash, direction: "debit", amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 },
    ])
    snap = BalanceSnapshots::Capture.call(w1)
    Transfers::Create.call(from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR")

    result = described_class.verify_snapshot(snap)
    expect(result[:ok]).to be(true)
    expect(result[:expected]).to eq(w1.balance)
  end
end
