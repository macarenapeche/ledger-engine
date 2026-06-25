class ReversalsController < ApplicationController
  # POST /journal_entries/:journal_entry_id/reversals
  # Posts the mirror of an entry to undo it without editing history. Idempotent per entry.
  def create
    original = JournalEntry.find(params[:journal_entry_id])
    reversal = Reversals::Create.call(original)

    render json: {
      id: reversal.id,
      reverses: reversal.reverses_entry_id,
      originator: reversal.originator_id,
      description: reversal.description,
      currency: reversal.currency,
      occurred_at: reversal.occurred_at,
      postings: reversal.postings.map { |p|
        { account: p.account.external_id, direction: p.direction, amount: p.amount }
      }
    }, status: :created
  end
end
