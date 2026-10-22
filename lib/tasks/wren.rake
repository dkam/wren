# Wren without the web: the same lists and claims, straight from the database.
# LIST is a list's token; with only one list it can be left out.
#
#   bin/rails wren:new [TITLE=...] [NAMES=] [TAGS=]   a list, with names as for add; prints its token
#   bin/rails wren:add [NAMES="a b"] [TAGS="x y"]     NAMES, and the catalog's names carrying every one of TAGS
#   bin/rails wren:claim SESSION=... [NOTE=] [HOST=] [EXCLUDE=a,b]
#   bin/rails wren:reserve NAME=... [NOTE=]
#   bin/rails wren:release NAME=...
#   bin/rails wren:list                               who holds which name
namespace :wren do
  def wren_list
    return List.find_by(token: ENV["LIST"]) || abort("wren: no list #{ENV["LIST"]}") if ENV["LIST"].present?

    lists = List.order(:created_at).to_a
    return lists.first if lists.one?

    abort lists.empty? ? "wren: no lists yet; make one with bin/rails wren:new" :
      "wren: which list? Set LIST to one of:\n" + lists.map { "  #{it.token}  #{it.title}" }.join("\n")
  end

  def wren_env(key) = ENV.fetch(key) { abort "wren: #{key} is required" }

  # Adds NAMES, and the catalog's names carrying every one of TAGS, the way
  # Take all does on the page. Returns how many were new.
  def wren_add(list)
    tags = ENV["TAGS"].to_s.downcase.split(/[\s,]+/).compact_blank
    tagged = tags.any? ? Catalog.tagged(tags) : []
    warn "wren: no name in the catalog carries every one of #{tags.join(" ")}" if tags.any? && tagged.empty?

    before = list.names.count
    invalid = list.add_names([ ENV["NAMES"], *tagged ])
    warn "wren: not names, so skipped: #{invalid.join(", ")}" if invalid.any?
    list.names.count - before
  end

  desc "Make a list, with NAMES and the catalog's names carrying every one of TAGS, and print its token"
  task new: :environment do
    list = List.create!(title: ENV["TITLE"].presence)
    wren_add(list)
    puts list.token
  end

  desc "Add NAMES, and the catalog's names carrying every one of TAGS"
  task add: :environment do
    abort "wren: NAMES or TAGS is required" if ENV["NAMES"].blank? && ENV["TAGS"].blank?
    puts "added #{wren_add(wren_list)}"
  end

  desc "A name for SESSION: the one it holds, or a free one"
  task claim: :environment do
    claim = wren_list.claim(session: wren_env("SESSION"), note: ENV["NOTE"], host: ENV["HOST"], exclude: ENV["EXCLUDE"])
    claim ? puts(claim.display_name) : abort("wren: every name is taken; release some with bin/rails wren:release NAME=...")
  end

  desc "Keep NAME until it is released"
  task reserve: :environment do
    claim = wren_list.reserve(name: wren_env("NAME"), note: ENV["NOTE"], host: ENV["HOST"])
    claim ? puts(claim.display_name) : abort("wren: #{ENV["NAME"]} is taken")
  end

  desc "Give NAME back"
  task release: :environment do
    name = wren_env("NAME")
    wren_list.release(name) ? puts("released #{name.capitalize}") : abort("wren: #{name} is not claimed")
  end

  desc "Who holds which name"
  task list: :environment do
    format = "%-14s %-16s %-6s %-20s %s\n"
    printf format, "NAME", "SEEN", "STATE", "HOST", "NOTE"
    wren_list.claims.each do |c|
      printf format, c.display_name, c.seen_at.localtime.strftime("%Y-%m-%d %H:%M"), c.state, c.host, c.note
    end
  end
end
