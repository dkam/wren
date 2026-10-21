require "test_helper"

class ListTest < ActiveSupport::TestCase
  setup do
    @list = List.create!
    @list.add_names("alba bram cora")
  end

  test "a token is twelve random letters and digits" do
    assert_match(/\A#{List::TOKEN}\z/, @list.token)
    assert_not_equal @list.token, List.create!.token
  end

  test "different sessions get different names" do
    names = %w[a b c].map { @list.claim(session: it).name }
    assert_equal %w[alba bram cora], names.sort
  end

  test "the same session gets the same name back, and is seen again" do
    first = @list.claim(session: "s1", note: "pi")
    travel 1.day
    again = @list.claim(session: "s1")
    assert_equal first.name, again.name
    assert_equal "pi", again.note, "a claim without a note keeps the old one"
    assert_in_delta Time.current, again.seen_at, 1
  end

  test "nil once every name is taken" do
    3.times { @list.claim(session: "s#{it}") }
    assert_nil @list.claim(session: "s4")
  end

  test "a claim lapses after the TTL and its name is given out again" do
    3.times { @list.claim(session: "s#{it}") }
    travel Claim::TTL + 1.day
    assert @list.claim(session: "new")
    assert_equal 1, @list.claims.count
  end

  test "excluded names are never given out" do
    5.times { assert_equal "cora", @list.claim(session: "s#{it}", exclude: "alba, BRAM").name; @list.claims.delete_all }
  end

  test "a reserved name is not given out, and never lapses" do
    assert @list.reserve(name: "Alba")
    assert_nil @list.reserve(name: "alba")
    travel Claim::TTL * 2
    names = 2.times.map { @list.claim(session: "s#{it}").name }
    assert_equal %w[bram cora], names.sort
  end

  test "a name outside the list can be reserved" do
    assert_equal "wren", @list.reserve(name: "wren").name
  end

  test "release gives a name back" do
    name = @list.claim(session: "s1").name
    assert @list.release(name.upcase)
    assert_not @list.release(name)
  end

  test "the database refuses a second claim on one name" do
    @list.claims.create!(name: "alba", session: "s1", seen_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) { @list.claims.create!(name: "alba", session: "s2", seen_at: Time.current) }
  end

  test "the database refuses a second claim by one session" do
    @list.claims.create!(name: "alba", session: "s1", seen_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) { @list.claims.create!(name: "bram", session: "s1", seen_at: Time.current) }
  end

  test "add_names splits, lowercases, dedupes and returns what is not a name" do
    assert_equal [ "9lives", "o'neil" ], @list.add_names("Dora, dora\nelias 9lives o'neil alba")
    assert_equal %w[alba bram cora dora elias], @list.names.pluck(:value)
  end
end
