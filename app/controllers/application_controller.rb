class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Ledger::AccountNotFound, with: :not_found
  rescue_from Ledger::InsufficientFunds, with: :unprocessable
  rescue_from Ledger::UnbalancedEntry, with: :unprocessable
  rescue_from Ledger::CurrencyMismatch, with: :unprocessable
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable

  private

    def not_found(error) = render json: { error: error.message }, status: :not_found
    def unprocessable(error) = render json: { error: error.message }, status: :unprocessable_entity
end
