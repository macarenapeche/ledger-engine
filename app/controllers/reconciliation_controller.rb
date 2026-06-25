class ReconciliationController < ApplicationController
  # GET /reconciliation — the trial balance. balanced=false means the books don't net to
  # zero and money has leaked: page someone.
  def show
    render json: {
      balanced: Reconciliation.balanced?,
      trial_balance: Reconciliation.trial_balance
    }
  end
end
