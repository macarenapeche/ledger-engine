class TransfersController < ApplicationController
  # POST /transfers
  # { "from": "wallet_1", "to": "wallet_2", "amount": 100, "currency": "EUR" }
  # Idempotency-Key header (or "idempotency_key" in the body) makes retries safe.
  def create
    entry = Transfers::Create.call(
      from: params.require(:from),
      to: params.require(:to),
      amount: Integer(params.require(:amount)),       # minor units (cents)
      currency: params.require(:currency),
      idempotency_key: request.headers["Idempotency-Key"] || params[:idempotency_key]
    )
    render json: serialize(entry), status: :created
  end

  private

  def serialize(entry)
    {
      id: entry.id,
      description: entry.description,
      currency: entry.currency,
      idempotency_key: entry.idempotency_key,
      occurred_at: entry.occurred_at,
      postings: entry.postings.map { |p|
        { account: p.account.external_id, direction: p.direction, amount: p.amount }
      }
    }
  end
end
