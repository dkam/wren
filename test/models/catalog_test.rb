require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  NAMES = {
    "hermione" => [ %w[harry-potter hero female] ],
    "bellatrix" => [ %w[harry-potter villain female] ],
    "draco" => [ %w[harry-potter villain male] ],
    "vesper" => [ %w[james-bond female] ],
    "blofeld" => [ %w[james-bond villain male] ],
    "bill" => [ %w[harry-potter hero male], %w[doctor-who female] ]
  }

  def tagged(*tags) = Catalog.tagged(tags, NAMES).sort

  test "a name must carry every tag" do
    assert_equal %w[bellatrix hermione], tagged("harry-potter", "female")
    assert_equal %w[blofeld draco], tagged("villain", "male")
  end

  test "a name shared by characters is tagged when any one of them carries every tag" do
    assert_equal %w[bill], tagged("doctor-who", "female")
    assert_equal %w[bill draco], tagged("harry-potter", "male")
    assert_equal [], tagged("doctor-who", "male")
  end

  test "no tags is every name, and a tag no name carries is none" do
    assert_equal NAMES.keys.sort, tagged
    assert_equal [], tagged("star-trek")
  end

  test "names.txt has a line for each character: a name used twice keeps each one's tags" do
    assert_includes Catalog::NAMES["bill"], %w[harry-potter male hero]
    assert_includes Catalog::NAMES["bill"], %w[doctor-who female]
  end

  test "each tag counts the names carrying it" do
    assert_equal Catalog::NAMES.count { |_, characters| characters.flatten.include?("female") }, Catalog::TAGS["female"]
  end

  test "names.txt holds each line once, sorted, and only names and tags" do
    lines = Catalog::FILE.readlines(chomp: true).reject(&:blank?)
    assert_equal lines.uniq, lines, "a line appears twice"
    assert_equal lines.sort, lines, "sort it with: LC_ALL=C sort -o config/names.txt config/names.txt"
    assert lines.flat_map(&:split).all? { it.match?(Name::FORMAT) }
  end

  test "a given name says where it is from, when that is clear, as a country or people and a region" do
    assert_equal [ %w[given-name female finnish nordic] ], Catalog::NAMES["suvi"]
    assert_equal [ %w[given-name male scottish british] ], Catalog::NAMES["lachlan"]
    assert_equal [ %w[given-name female nordic] ], Catalog::NAMES["astrid"]
    assert_equal [ %w[given-name female] ], Catalog::NAMES["nina"], "a name common in many places has no origin"
  end

  test "the given names are tagged given-name, and female or male where the name is clearly one" do
    assert_equal [ %w[given-name male] ], Catalog::NAMES["hugo"]
    assert_equal [ %w[given-name] ], Catalog::NAMES["quinn"]
  end
end
