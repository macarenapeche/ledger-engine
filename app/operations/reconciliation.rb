module Reconciliation
  module_function

  # The trial balance: in a closed double-entry system every entry nets to zero, so the
  # signed sum of ALL postings must be zero *per currency*. A non-zero result means the
  # books are broken — money appeared or vanished. This is the check that catches it.
  def trial_balance
    Posting.group(:currency).sum(:delta)
  end

  def balanced?
    trial_balance.values.all?(&:zero?)
  end

  # Verify a snapshot still reconciles against live postings: the stored balance plus every
  # posting after the snapshot's high-water mark must equal the recomputed live balance.
  def verify_snapshot(snapshot)
    account = snapshot.account
    after = account.postings.where("id > ?", snapshot.last_posting_id).sum(:delta)
    after = account.normal_balance == "debit" ? after : -after
    expected = snapshot.balance + after
    live = account.balance
    { account: account.external_id, ok: expected == live, expected:, live: }
  end
end
