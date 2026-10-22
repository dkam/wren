# A list of names, and the agents holding them. The token is the only key: it
# is in the list's URL, and anyone who has it can read, edit and claim. It is
# random rather than an encoded id so that lists cannot be found by counting.
class List < ApplicationRecord
  TOKEN = /[A-Za-z0-9]{12}/
  MAX_NAMES = 1000

  has_many :names, -> { order(:value) }, dependent: :delete_all
  has_many :claims, -> { order(:name) }, dependent: :delete_all

  before_validation(on: :create) { self.token ||= SecureRandom.alphanumeric(12) }
  validates :title, length: { maximum: 100 }

  def to_param = token

  # What GET /list and /<token>.json give: the names and who holds which.
  def as_json(*) = { title:, names: names.pluck(:value), claims: }

  # The name held by this session, or else a free one picked at random. Asking
  # again keeps the claim alive. Returns nil when every name is taken.
  def claim(session:, note: nil, host: nil, exclude: [])
    transaction do
      if (held = claims.live.find_by(session:))
        held.update!(seen_at: Time.current, note: note.presence || held.note, host: host.presence || held.host)
        return held
      end

      claims.lapsed.delete_all
      (names.pluck(:value) - claims.pluck(:name) - words(exclude)).shuffle.each do |name|
        return claims.create!(name:, session:, note:, host:, seen_at: Time.current)
      rescue ActiveRecord::RecordNotUnique
        # Lost a race. If it was this session racing itself, the winner's
        # claim is the answer; otherwise try another name.
        if (held = claims.live.find_by(session:)) then return held end
      end
      nil
    end
  end

  # One particular name, kept until released. Returns nil if it is held.
  def reserve(name:, note: nil, host: nil)
    transaction do
      claims.lapsed.where(name: Claim.normalize_value_for(:name, name)).delete_all
      refuse!("A list can hold at most #{MAX_NAMES} claims") if claims.count >= MAX_NAMES
      claims.create!(name:, session: nil, note:, host:, seen_at: Time.current)
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def release(name)
    claims.where(name: Claim.normalize_value_for(:name, name)).delete_all.positive?
  end

  # Adds every name in a blob of text split on spaces, commas or lines, or
  # none of them if they would take the list past MAX_NAMES. Returns the ones
  # that were not names at all.
  def add_names(text)
    valid, invalid = words(text).partition { it.match?(Name::FORMAT) }
    new = valid - names.where(value: valid).pluck(:value)
    refuse!("A list can hold at most #{MAX_NAMES} names") if names.count + new.size > MAX_NAMES
    names.insert_all(new.map { { value: it, created_at: Time.current, updated_at: Time.current } }) if new.any?
    invalid
  end

  private
    def refuse!(message)
      errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, self
    end

    def words(text) = Array(text).flat_map { it.to_s.downcase.split(/[\s,]+/) }.reject(&:blank?).uniq
end
