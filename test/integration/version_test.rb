require "test_helper"

# Two numbers, as in clinch, splat and booko. Wren::VERSION (config/version.rb)
# names the release; config.x.revision names the commit, so "is what I just
# built actually running?" has an answer.
class VersionTest < ActionDispatch::IntegrationTest
  test "the footer names the release, and the revision on hover" do
    get "/"

    assert_response :success
    assert_select "footer span[title=?]", "Wren #{Wren::VERSION}, revision #{Rails.application.config.x.revision.first(9)}",
      text: "v#{Wren::VERSION}"
  end

  test "a git checkout with no VERSION file reports its commit" do
    skip "not a git checkout" unless Rails.root.join(".git").exist?
    skip "built image: the VERSION file answers this" if Rails.root.join("VERSION").exist?

    assert_match(/\A[0-9a-f]{7,40}\z/, Rails.application.config.x.revision)
  end
end
