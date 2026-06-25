class AccountsController < ApplicationController
  # POST /accounts
  def create
    account = Account.create!(account_params)
    render json: serialize(account), status: :created
  end

  # GET /accounts/:external_id
  def show
    render json: serialize(find_account)
  end

  # GET /accounts/:external_id/balance
  def balance
    account = find_account
    render json: { account: account.external_id, currency: account.currency, balance: account.balance }
  end

  private

  def find_account = Account.find_by!(external_id: params[:external_id])

  def account_params
    params.permit(:external_id, :holder_ref, :name, :currency, :normal_balance, metadata: {})
  end

  def serialize(account)
    {
      external_id: account.external_id,
      holder_ref: account.holder_ref,
      name: account.name,
      currency: account.currency,
      normal_balance: account.normal_balance,
      balance: account.balance
    }
  end
end
