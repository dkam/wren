require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
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
end
