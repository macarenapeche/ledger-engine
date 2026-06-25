class Posting < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :account

  DIRECTIONS = %w[debit credit].freeze

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validate :currency_matches_account

  def readonly? = persisted?
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "postings are append-only" }

  private

  def currency_matches_account
    return if account.nil? || currency == account.currency

    errors.add(:currency, "must match the account currency (#{account.currency})")
  end
end
