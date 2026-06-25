require "rails_helper"

RSpec.describe "POST /transfers", type: :request do
  let(:cash) { account!("cash", normal: "debit") }

  before do
    account!("wallet_1_eur", holder: "wallet_1")
    account!("wallet_2_eur", holder: "wallet_2")
    w1 = Account.find_by!(external_id: "wallet_1_eur")
    Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash, direction: "debit", amount: 10_000 },
      { account: w1,   direction: "credit", amount: 10_000 },
    ])
  end

  it "transfers and returns the journal entry" do
    post "/transfers", params: { from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR" }, as: :json

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["postings"]).to contain_exactly(
      { "account" => "wallet_1_eur", "direction" => "debit",  "amount" => 2_500 },
      { "account" => "wallet_2_eur", "direction" => "credit", "amount" => 2_500 },
    )
    get "/accounts/wallet_2_eur/balance"
    expect(JSON.parse(response.body)["balance"]).to eq(2_500)
  end

  it "honours the Idempotency-Key header on retry" do
    headers = { "Idempotency-Key" => "abc-123" }
    post "/transfers", params: { from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR" }, headers:, as: :json
    post "/transfers", params: { from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR" }, headers:, as: :json

    get "/accounts/wallet_2_eur/balance"
    expect(JSON.parse(response.body)["balance"]).to eq(2_500) # applied once
  end

  it "returns 422 on insufficient funds" do
    post "/transfers", params: { from: "wallet_1", to: "wallet_2", amount: 999_999, currency: "EUR" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
