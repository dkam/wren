# One name an agent may be given.
class Name < ApplicationRecord
  FORMAT = /\A[a-z][a-z0-9-]{0,31}\z/

  belongs_to :list

  normalizes :value, with: -> { it.strip.downcase }
  validates :value, format: FORMAT, uniqueness: { scope: :list_id }

  def to_param = value
end
