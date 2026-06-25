class BalanceSnapshot < ApplicationRecord
  belongs_to :account

  validates :balance, :last_posting_id, :postings_count, :captured_at, presence: true
end
