# The names every list can take from, read from config/names.txt: a line for
# each character, its name and then its tags. Characters can share a name, so
# a name has the tags of each, kept apart: Bill is male in Harry Potter and
# female in Doctor Who, not both in either. Lists take copies of its names: to
# change it, edit the file and deploy, and each list keeps the names it has.
module Catalog
  FILE = Rails.root.join("config/names.txt")
  NAMES = FILE.readlines(chomp: true).filter_map { it.split.presence }
    .group_by(&:first).transform_values { |lines| lines.map { it.drop(1).freeze }.freeze }.freeze
  TAGS = NAMES.values.flat_map { it.flatten.uniq }.tally.sort.to_h.freeze

  # The names with a character carrying every one of the tags.
  def self.tagged(tags, names = NAMES)
    names.filter_map { |name, characters| name if characters.any? { (tags - it).empty? } }
  end
end
