require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "make a list, fill it, see who holds what, release, remove" do
    get "/"
    assert_response :success

    post "/", params: { title: "Silo agents" }
    list = List.last
    assert_redirected_to "/#{list.token}"
    follow_redirect!
    assert_select "input[name=title][value=?]", "Silo agents"

    post "/#{list.token}/names/defaults"
    assert_equal List::DEFAULT_NAMES.size, list.names.count

    post "/#{list.token}/names", params: { names: "wren, 1x" }
    follow_redirect!
    assert_select "p", /Not names, so skipped: 1x/

    list.reserve(name: "wren", note: "taken by hand")
    get "/#{list.token}"
    assert_select "li", /Wren.*kept.*taken by hand/m

    delete "/#{list.token}/claims/wren"
    assert_equal 0, list.claims.count
    delete "/#{list.token}/names/wren"
    assert_not list.names.exists?(value: "wren")
  end
end
