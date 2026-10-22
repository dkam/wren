require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    ApplicationController::RATE_LIMITS.clear
    @list = List.create!
    @list.add_names("alba bram")
  end

  test "claim, claim again, list, release" do
    post "/#{@list.token}/claim", params: { session: "s1", note: "pi", host: "tachi" }
    assert_response :success
    name = response.parsed_body["name"]
    assert_equal name.capitalize, response.parsed_body["display_name"]

    post "/#{@list.token}/claim", params: { session: "s1" }
    assert_equal name, response.parsed_body["name"]

    get "/#{@list.token}.json"
    assert_equal [ name ], response.parsed_body["claims"].map { it["name"] }

    post "/#{@list.token}/release", params: { name: }
    assert_response :no_content
    post "/#{@list.token}/release", params: { name: }
    assert_response :not_found
  end

  test "claim takes JSON with exclude as a list" do
    post "/#{@list.token}/claim", params: { session: "s1", exclude: [ "alba" ] }, as: :json
    assert_equal "bram", response.parsed_body["name"]
  end

  test "the JSON has the title, the names and the claims" do
    @list.update!(title: "Silo")
    @list.claim(session: "s1")
    get "/#{@list.token}.json"
    assert_equal %w[claims names title], response.parsed_body.keys.sort
    assert_equal "Silo", response.parsed_body["title"]
    assert_equal %w[alba bram], response.parsed_body["names"]
    assert_equal 1, response.parsed_body["claims"].size
  end

  test "claim needs a session" do
    post "/#{@list.token}/claim"
    assert_response :bad_request
  end

  test "409 when every name is taken" do
    %w[s1 s2].each { post "/#{@list.token}/claim", params: { session: it } }
    post "/#{@list.token}/claim", params: { session: "s3" }
    assert_response :conflict
  end

  test "reserve: 409 if held, 422 if not a name" do
    post "/#{@list.token}/reserve", params: { name: "alba" }
    assert_equal "kept", response.parsed_body["state"]
    post "/#{@list.token}/reserve", params: { name: "alba" }
    assert_response :conflict
    post "/#{@list.token}/reserve", params: { name: "9 lives" }
    assert_response :unprocessable_content
  end

  test "an unknown list is a 404" do
    post "/AAAAAAAAAAAA/claim", params: { session: "s1" }
    assert_response :not_found
  end

  test "a note too long is a 422" do
    post "/#{@list.token}/claim", params: { session: "s1", note: "x" * 201 }
    assert_response :unprocessable_content
    assert_match(/Note is too long/, response.parsed_body["error"])
  end

  test "a session too long is a 422" do
    post "/claim", params: { key: @list.token, session: "x" * 65 }
    assert_response :unprocessable_content
    assert_match(/Session is too long/, response.parsed_body["error"])
  end

  test "an address makes at most sixty calls a minute" do
    60.times { post "/#{@list.token}/claim", params: { session: "s1" } }
    assert_response :success
    post "/#{@list.token}/release", params: { name: "alba" }
    assert_response :too_many_requests
  end

  test "the key can be a parameter rather than in the path" do
    post "/claim", params: { key: @list.token, session: "s1" }
    assert_response :success
    name = response.parsed_body["name"]

    post "/release", params: { key: @list.token, name: }
    assert_response :no_content
    post "/reserve", params: { key: @list.token, name: "wren" }
    assert_equal "kept", response.parsed_body["state"]
  end

  test "the key can be an Authorization header, for the JSON too" do
    auth = { "Authorization" => "Bearer #{@list.token}" }
    post "/claim", params: { session: "s1" }, headers: auth
    assert_response :success
    name = response.parsed_body["name"]

    get "/list", headers: auth
    assert_equal %w[alba bram], response.parsed_body["names"]
    assert_equal [ name ], response.parsed_body["claims"].map { it["name"] }

    post "/release", params: { name: }, headers: auth
    assert_response :no_content
  end

  test "no key, or a wrong one, is a 404" do
    post "/claim", params: { session: "s1" }
    assert_response :not_found
    post "/claim", params: { key: "AAAAAAAAAAAA", session: "s1" }
    assert_response :not_found
    post "/claim", params: { session: "s1" }, headers: { "Authorization" => "Bearer AAAAAAAAAAAA" }
    assert_response :not_found
    get "/list"
    assert_response :not_found
  end

  test "one request tries one key" do
    post "/claim", params: { key: [ "AAAAAAAAAAAA", @list.token ], session: "s1" }
    assert_response :not_found
  end

  # Anyone with IPv6 has a /64 of addresses to spread calls across.
  test "addresses in one IPv6 /64 share the sixty calls a minute; IPv4 addresses do not" do
    claim = ->(address) { post "/claim", params: { key: @list.token, session: "s1" }, env: { "REMOTE_ADDR" => address } }

    60.times { claim.("2001:db8::1") }
    claim.("2001:db8::ffff")
    assert_response :too_many_requests

    60.times { claim.("192.0.2.1") }
    claim.("192.0.2.2")
    assert_response :success
  end

  # Nothing the API does needs a session, and nonces for the page must not make one.
  test "the API sets no cookie" do
    post "/claim", params: { key: @list.token, session: "s1" }
    assert_response :success
    assert_nil response.headers["Set-Cookie"]
  end

  test "wrong keys count toward the sixty calls a minute" do
    60.times { post "/claim", params: { key: "AAAAAAAAAAAA", session: "s1" } }
    assert_response :not_found
    post "/claim", params: { key: @list.token, session: "s1" }
    assert_response :too_many_requests
  end

  test "the key is kept out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal "[FILTERED]", filter.filter("key" => @list.token)["key"]
  end
end
