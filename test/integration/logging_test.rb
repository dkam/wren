require "test_helper"

# A list's key is the whole of its credential. It goes in a header, a field or
# the path, and none of those may reach the log: not the request line, not
# the parameters, not a redirect.
class LoggingTest < ActionDispatch::IntegrationTest
  setup do
    ApplicationController::RATE_LIMITS.clear
    @list = List.create!
    @list.add_names("alba bram")
  end

  test "the key stays out of the log" do
    key = @list.token
    log = capturing_log do
      get "/#{key}"
      get "/#{key}.json"
      post "/#{key}/names", params: { names: "wren" }
      post "/#{key}/claim", params: { session: "s1" }
      post "/claim", params: { key:, session: "s2" }
      get "/list", headers: { "Authorization" => "Bearer #{key}" }
      post "/find", params: { key: }
      post "/", params: { title: "another" }
    end

    assert_match %r{Started GET "/\[FILTERED\]\.json"}, log
    leaked = log.lines.select { |line| [ key, List.last.token ].any? { line.include?(it) } }
    assert_empty leaked, "lines carrying a key:\n#{leaked.join}"
  end

  private
    def capturing_log
      io = StringIO.new
      logger = ActiveSupport::Logger.new(io)
      Rails.logger.broadcast_to(logger)
      yield
      io.string
    ensure
      Rails.logger.stop_broadcasting_to(logger)
    end
end
