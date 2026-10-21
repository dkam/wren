# A list of names, and the agents holding them. The token is the only key: it
# is in the list's URL, and anyone who has it can read, edit and claim. It is
# random rather than an encoded id so that lists cannot be found by counting.
class List < ApplicationRecord
  TOKEN = /[A-Za-z0-9]{12}/
  DEFAULT_NAMES = Rails.root.join("config/names.txt").readlines(chomp: true).reject(&:blank?).freeze

  has_many :names, -> { order(:value) }, dependent: :delete_all
  has_many :claims, -> { order(:name) }, dependent: :delete_all

  before_validation(on: :create) { self.token ||= SecureRandom.alphanumeric(12) }

  def to_param = token

  # The name held by this session, or else a free one picked at random. Asking
  # again keeps the claim alive. Returns nil when every name is taken.
  def claim(session:, note: nil, host: nil, exclude: [])
    transaction do
      if (held = claims.live.find_by(session:))
        held.update!(seen_at: Time.current, note: note.presence || held.note, host: host.presence || held.host)
        return held
      end

      claims.lapsed.delete_all
      taken = claims.pluck(:name) + Array(exclude).flat_map { it.to_s.downcase.split(/[\s,]+/) }
      (names.pluck(:value) - taken).shuffle.each do |name|
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
      claims.create!(name:, session: nil, note:, host:, seen_at: Time.current)
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def release(name)
    claims.where(name: Claim.normalize_value_for(:name, name)).delete_all.positive?
  end

  # Adds every name in a blob of text split on spaces, commas or lines. Returns
  # the ones that were not names at all.
  def add_names(text)
    words = text.to_s.split(/[\s,]+/).map { it.strip.downcase }.reject(&:blank?).uniq
    valid, invalid = words.partition { it.match?(Name::FORMAT) }
    rows = valid.map { { value: it, created_at: Time.current, updated_at: Time.current } }
    names.insert_all(rows, unique_by: %i[list_id value]) if rows.any?
    invalid
  end
end
