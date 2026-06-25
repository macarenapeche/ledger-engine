require "rails_helper"

RSpec.describe "POST /journal_entries/:id/reversals", type: :request do
  let(:cash) { account!("cash", normal: "debit") }
  let!(:w1)  { account!("wallet_1_eur", holder: "wallet_1") }

  let(:entry) do
    Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash, direction: "debit",  amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 }
    ])
  end

  it "reverses an entry and zeroes the balance" do
    post "/journal_entries/#{entry.id}/reversals"

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["reverses"]).to eq(entry.id)

    get "/accounts/wallet_1_eur/balance"
    expect(JSON.parse(response.body)["balance"]).to eq(0)
  end

  it "returns 404 for an unknown entry" do
    post "/journal_entries/999999/reversals"
    expect(response).to have_http_status(:not_found)
  end

  it "reverses a reversal, linking back to the originator" do
    reversal = Reversals::Create.call(entry)
    post "/journal_entries/#{reversal.id}/reversals"

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["reverses"]).to eq(reversal.id)   # immediate parent
    expect(body["originator"]).to eq(entry.id)    # root of the chain
  end
end
