# A name held by an agent session, or reserved by hand (no session). A
# session's claim lapses after TTL without being asked for again; a reserved
# one never does.
class Claim < ApplicationRecord
  TTL = ENV.fetch("WREN_TTL_DAYS", 30).to_i.days

  belongs_to :list

  normalizes :name, with: -> { it.strip.downcase }
  validates :name, format: Name::FORMAT

  scope :live, -> { where(session: nil).or(where(seen_at: TTL.ago..)) }
  scope :lapsed, -> { where.not(session: nil).where(seen_at: ...TTL.ago) }

  def reserved? = session.nil?
  def lapsed? = !reserved? && seen_at < TTL.ago
  def state = reserved? ? "kept" : (lapsed? ? "lapsed" : "live")
  def display_name = name.capitalize

  def as_json(*)
    { name:, display_name:, state:, session:, note:, host:, seen_at: }
  end
end
