# Demo ledger: a platform cash account (asset) funds two customer wallets (liabilities),
# then we move money between wallets.
cash = Account.find_or_create_by!(external_id: "cash_eur") do |a|
  a.holder_ref = "platform"; a.name = "Platform Cash EUR"; a.currency = "EUR"; a.normal_balance = "debit"
end

%w[wallet_1 wallet_2].each do |h|
  Account.find_or_create_by!(external_id: "#{h}_eur") do |a|
    a.holder_ref = h; a.name = "#{h} EUR"; a.currency = "EUR"; a.normal_balance = "credit"
  end
end

# wallet_1 also holds USD — different currency = a separate account under the same holder.
Account.find_or_create_by!(external_id: "wallet_1_usd") do |a|
  a.holder_ref = "wallet_1"; a.name = "wallet_1 USD"; a.currency = "USD"; a.normal_balance = "credit"
end

# Fund wallet_1 with 100.00 EUR: customer's cash enters the platform (debit asset) and we now
# owe them that balance (credit liability). Books stay balanced.
wallet_1_eur = Account.find_by!(external_id: "wallet_1_eur")
Ledger::PostEntry.call(
  description: "fund wallet_1", currency: "EUR", idempotency_key: "seed-fund-wallet_1",
  lines: [
    { account: cash,         direction: "debit",  amount: 10_000 },
    { account: wallet_1_eur, direction: "credit", amount: 10_000 },
  ]
)

# Move 25.00 EUR wallet_1 -> wallet_2.
Transfers::Create.call(from: "wallet_1", to: "wallet_2", amount: 2_500, currency: "EUR", idempotency_key: "seed-transfer-1")

puts "Seeded. Trial balance: #{Reconciliation.trial_balance} (balanced: #{Reconciliation.balanced?})"
