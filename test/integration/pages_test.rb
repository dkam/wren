require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  setup { ApplicationController::RATE_LIMITS.clear }

  # What Turbo sends with a form, so the answer is a stream that changes the page in place.
  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html" }

  test "make a key, take names from the catalog and of its own, see who holds what, release, remove" do
    get "/"
    assert_response :success

    post "/", params: { title: "Silo agents" }
    list = List.last
    assert_redirected_to "/#{list.token}"
    follow_redirect!
    assert_select "input[name=title][value=?]", "Silo agents"
    assert_select "#chosen", /No names yet/
    assert_select "#catalog button[name=names][value=hermione][data-tags=?]", Catalog::NAMES["hermione"].join(" ")
    assert_select "#catalog input[type=search][aria-label=?]", "Search names"
    assert_select "#catalog input[role=combobox][aria-label=?][aria-controls=tag-options]", "Tags"
    assert_select "#tag-options[role=listbox] [role=option][data-tag=harry-potter]"

    # Clicking a name, dragging it, or taking all the catalog shows, posts them.
    post "/#{list.token}/names", params: { names: "hermione luna" }, headers: STREAM
    assert_turbo_stream action: :replace, target: "chosen" do
      assert_select "template li", 2
    end

    get "/#{list.token}"
    assert_select "#chosen li", 2
    assert_select "#chosen button[formaction=?]", "/#{list.token}/names/hermione"
    assert_select "#catalog button[value=hermione][hidden]"
    assert_select "#catalog button[value=draco]:not([hidden])"

    post "/#{list.token}/names", params: { names: "wren, 1x" }, headers: STREAM
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "template p", /Not names, so skipped: 1x/
    end
    assert_turbo_stream action: :replace, target: "chosen" do
      assert_select "template li", 3
    end

    list.reserve(name: "wren", note: "taken by hand")
    get "/#{list.token}"
    assert_select "li", /Wren.*kept.*taken by hand/m

    delete "/#{list.token}/claims/wren"
    assert_equal 0, list.claims.count
    delete "/#{list.token}/names/wren", headers: STREAM
    assert_turbo_stream action: :replace, target: "chosen" do
      assert_select "template li", 2
    end
    assert_not list.names.exists?(value: "wren")
  end

  test "without Turbo, adding and removing names reloads the page" do
    list = List.create!
    post "/#{list.token}/names", params: { names: "wren 1x" }
    assert_redirected_to "/#{list.token}"
    follow_redirect!
    assert_select "p", /Not names, so skipped: 1x/
    delete "/#{list.token}/names/wren"
    assert_redirected_to "/#{list.token}"
    assert_equal 0, list.names.count
  end

  # Posted, so the key is in the body rather than the address, and the log.
  test "open a key by its token or its address; an unknown one is refused" do
    list = List.create!
    post "/find", params: { key: " #{list.token} " }
    assert_redirected_to "/#{list.token}"
    post "/find", params: { key: "https://wre.nmilne.com/#{list.token}" }
    assert_redirected_to "/#{list.token}"

    post "/find", params: { key: "AAAAAAAAAAAA" }
    assert_redirected_to "/"
    follow_redirect!
    assert_select "p", /No such key/

    get "/"
    assert_select "form[action='/find'][method=post] input[name=key]"
  end

  # So the picker can match tags against one character at a time: harry-potter
  # and female must not find Bill, who is female only in Doctor Who.
  test "a name shared by characters carries each one's tags apart" do
    get "/#{List.create!.token}"
    assert_select "#catalog button[value=bill][data-tags=?]", "doctor-who female|harry-potter male hero"
  end

  test "the page tells agents to send the key as a header" do
    list = List.create!
    get "/#{list.token}"
    assert_select "pre code", /-H "Authorization: Bearer #{list.token}"/
    assert_select "pre code", text: /key=/, count: 0
  end

  # A key's page is the key, so it stays out of search engines even if its
  # address is pasted somewhere public.
  test "a list's page asks not to be indexed" do
    list = List.create!
    get "/#{list.token}"
    assert_equal "noindex", response.headers["X-Robots-Tag"]
    get "/#{list.token}.json"
    assert_equal "noindex", response.headers["X-Robots-Tag"]
  end

  # Scripts and styles from the app itself, or inline with the page's nonce;
  # nothing from anywhere else, and never in a frame.
  test "pages run under a content security policy whose nonce their scripts carry" do
    get "/"
    policy = response.headers["Content-Security-Policy"].to_s
    nonce = policy[/script-src 'self' 'nonce-([^']+)'/, 1]
    assert nonce.present?, "no script nonce in #{policy.inspect}"
    assert_includes policy, "style-src 'self' 'nonce-#{nonce}'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_select "script[type=importmap][nonce=?]", nonce
    assert_select "meta[name=csp-nonce][content=?]", nonce
  end

  test "a refusal on the page is shown in place" do
    list = List.create!
    list.add_names((1..List::MAX_NAMES).map { "n#{it}" })
    post "/#{list.token}/names", params: { names: "wren" }, headers: STREAM
    assert_turbo_stream action: :update, target: "flash", status: :unprocessable_content do
      assert_select "template p", /at most #{List::MAX_NAMES} names/
    end
  end

  test "an address makes at most sixty changes to names a minute, and is told so in place" do
    list = List.create!
    60.times { post "/#{list.token}/names", params: { names: "wren" }, headers: STREAM }
    assert_response :success
    delete "/#{list.token}/names/wren", headers: STREAM
    assert_turbo_stream action: :update, target: "flash", status: :too_many_requests do
      assert_select "template p", /Too many changes/
    end
  end

  test "wrong keys count toward the sixty changes a minute" do
    list = List.create!
    60.times { post "/AAAAAAAAAAAA/names", params: { names: "wren" }, headers: STREAM }
    assert_response :not_found
    post "/#{list.token}/names", params: { names: "wren" }, headers: STREAM
    assert_turbo_stream action: :update, target: "flash", status: :too_many_requests
  end

  test "too long a title is refused with a message, not an error page" do
    list = List.create!(title: "Silo")
    patch "/#{list.token}", params: { title: "x" * 101 }
    assert_redirected_to "/#{list.token}"
    follow_redirect!
    assert_select "p", /Title is too long/
    assert_equal "Silo", list.reload.title
  end

  test "a new key with too long a title is refused with a message" do
    post "/", params: { title: "x" * 101 }
    assert_redirected_to "/"
    follow_redirect!
    assert_select "p", /Title is too long/
    assert_equal 0, List.count
  end

  test "an address makes at most ten keys an hour" do
    10.times { post "/"; assert_response :redirect }
    post "/"
    assert_response :too_many_requests
    travel 1.hour + 1.second
    post "/"
    assert_response :redirect
  end
end
