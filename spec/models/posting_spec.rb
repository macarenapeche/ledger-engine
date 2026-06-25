require "rails_helper"

RSpec.describe Posting do
  let(:cash)   { account!("cash", normal: "debit") }
  let(:wallet) { account!("wallet", normal: "credit") }
  let(:posting) do
    entry = Ledger::PostEntry.call(description: "fund", currency: "EUR", lines: [
      { account: cash,   direction: "debit",  amount: 100 },
      { account: wallet, direction: "credit", amount: 100 },
    ])
    entry.postings.first
  end

  # Go straight to SQL, past ActiveRecord's own readonly? guard, to prove the trigger — not
  # just the Ruby model — refuses mutation.
  it "is immutable: the DB blocks updates even via raw SQL" do
    expect { ActiveRecord::Base.connection.execute("UPDATE postings SET amount = 1 WHERE id = #{posting.id}") }
      .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
  end

  it "is immutable: the DB blocks deletes even via raw SQL" do
    expect { ActiveRecord::Base.connection.execute("DELETE FROM postings WHERE id = #{posting.id}") }
      .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
  end
end
