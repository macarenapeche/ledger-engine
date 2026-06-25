class JournalEntry < ApplicationRecord
  has_many :postings, dependent: :restrict_with_exception

  # A reversal points at the entry it reverses; one reversal per original (DB-enforced).
  belongs_to :reverses_entry, class_name: "JournalEntry", optional: true
  has_one :reversal, class_name: "JournalEntry", foreign_key: :reverses_entry_id, inverse_of: :reverses_entry, dependent: :restrict_with_exception

  # The root of the reversal chain (X in X -> R1 -> R2 ...). Null on originals themselves.
  belongs_to :originator, class_name: "JournalEntry", optional: true

  validates :description, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :idempotency_key, uniqueness: true, allow_nil: true

  # Derive the originator from whatever this entry reverses, so the whole chain shares one
  # root regardless of how deep it goes. Set at creation; entries are immutable thereafter.
  before_create :inherit_originator

  def reversal? = reverses_entry_id.present?

  # App-level guard so a stray `entry.update`/`destroy` fails loudly in Ruby rather than
  # only at the DB trigger. The DB is still the source of truth (see AddLedgerInvariants).
  def readonly? = persisted?
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "journal entries are append-only" }

  def balanced?
    postings.sum(:delta).zero? && postings.count >= 2
  end

  private

  def inherit_originator
    return unless reverses_entry

    self.originator_id = reverses_entry.originator_id || reverses_entry.id
  end
end
