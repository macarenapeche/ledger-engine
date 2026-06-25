module BalanceSnapshots
  # Point-in-time balance for an account, pinned to a posting high-water mark so it can be
  # reused as a fast starting point (snapshot.balance + postings after it = current balance).
  # Idempotent: re-capturing at the same high-water mark returns the existing snapshot.
  class Capture
    def self.call(...) = new(...).call

    def initialize(account)
      @account = account
    end

    def call
      hwm = account.postings.maximum(:id) || 0
      BalanceSnapshot.find_or_create_by!(account:, last_posting_id: hwm) do |s|
        s.balance = account.balance(as_of_posting_id: hwm)
        s.postings_count = account.postings.where("id <= ?", hwm).count
        s.captured_at = Time.current
      end
    end

    private

    attr_reader :account
  end
end
