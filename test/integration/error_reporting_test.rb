require "test_helper"
require_relative "../support/sentry_configured"

# What gets sent to Splat. A list's key is the whole of its credential, and the
# first segment of every page's path, so what matters most is that no event
# carries it: not in the URL, the headers, the breadcrumbs or the message.
class ErrorReportingTest < ActionDispatch::IntegrationTest
  include SentryConfigured

  setup do
    ApplicationController::RATE_LIMITS.clear
    @list = List.create!
    @list.add_names("alba bram")
  end

  test "no DSN means the SDK never starts" do
    with_env("SENTRY_DSN" => nil) do
      load Rails.root.join("config/initializers/sentry.rb").to_s
      refute Sentry.initialized?
    end
  end

  test "the release names both the version and the commit" do
    with_sentry_configured do
      assert_equal "#{Wren::VERSION}+#{Rails.application.config.x.revision}", Sentry.configuration.release
    end
  end

  # From the page, so with the page as the Referer; and an error that names
  # the key, as one built from the params would.
  test "an error on a list's page is reported without the key" do
    key = @list.token
    with_sentry_configured do
      stubbing(List, :find_by!, ->(**) { raise "no list for #{key}" }) do
        assert_raises(RuntimeError) do
          post "/#{key}/names", params: { names: "wren" }, headers: { "Referer" => "http://www.example.com/#{key}" }
        end
      end

      assert_equal 1, sentry_events.size
      event = sentry_events.first
      assert_no_key event, key
      assert_equal "http://www.example.com/[Filtered]/names", event.request.url
      assert_equal "no list for [Filtered] (RuntimeError)", event.exception.values.first.value
    end
  end

  test "a traced request is reported without the key" do
    key = @list.token
    with_sentry_configured("SENTRY_TRACES_SAMPLE_RATE" => "1.0") do
      get "/#{key}.json", headers: { "Referer" => "http://www.example.com/#{key}" }

      transaction = sentry_events.find { it.is_a?(Sentry::TransactionEvent) }
      assert transaction, "the request was not traced"
      assert_no_key transaction, key
    end
  end

  # Its own address has no key in it, only the query, which is not sent; the
  # redirect it answers with does.
  test "opening a list from its key is reported without the key" do
    key = @list.token
    with_sentry_configured("SENTRY_TRACES_SAMPLE_RATE" => "1.0") do
      post "/find", params: { key: }
      assert_redirected_to "/#{key}"

      transaction = sentry_events.find { it.is_a?(Sentry::TransactionEvent) }
      assert transaction, "the request was not traced"
      assert_no_key transaction, key
    end
  end

  private
    # Names every place in the payload the key turns up.
    def assert_no_key(event, key)
      places = []
      find = lambda do |value, path|
        case value
        when Hash then value.each { |k, v| find.(v, "#{path}.#{k}") }
        when Array then value.each_with_index { |v, i| find.(v, "#{path}[#{i}]") }
        when String then places << "#{path}: #{value.truncate(120)}" if value.include?(key)
        end
      end
      find.(event.to_json_compatible, "event")
      assert_empty places, "the key is in the event:\n#{places.join("\n")}"
    end

    # Replaces a class method for the length of the block.
    def stubbing(object, name, replacement)
      object.define_singleton_method(name, &replacement)
      yield
    ensure
      object.singleton_class.remove_method(name)
    end
end
