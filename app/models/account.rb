class Account < ApplicationRecord
  has_many :postings, dependent: :restrict_with_exception
  has_many :balance_snapshots, dependent: :delete_all

  NORMAL_BALANCES = %w[debit credit].freeze

  validates :external_id, :holder_ref, :name, presence: true
  validates :external_id, uniqueness: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :normal_balance, inclusion: { in: NORMAL_BALANCES }
  validates :holder_ref, uniqueness: { scope: :currency,
    message: "already has an account in this currency" }

  # Live balance in the account's normal orientation (positive = a healthy balance).
  # delta is debit-positive; credit-normal accounts invert it.
  # ponytail: full-table SUM per call. Fine to thousands of postings; past that, read from
  # the latest BalanceSnapshot + only the postings after it (see BalanceSnapshots::Capture).
  def balance(as_of_posting_id: nil)
    scope = postings
    scope = scope.where("postings.id <= ?", as_of_posting_id) if as_of_posting_id
    signed = scope.sum(:delta)
    normal_balance == "debit" ? signed : -signed
  end
end
