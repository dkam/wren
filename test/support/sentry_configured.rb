require "sentry/test_helper"

# Sentry is not started in test (no SENTRY_DSN), so a test of what gets
# reported starts it, from the real config/initializers/sentry.rb rather than
# a Sentry.init of its own. Events go to DummyTransport; nothing leaves.
module SentryConfigured
  include Sentry::TestHelper

  def with_sentry_configured(env = {})
    with_env({ "SENTRY_DSN" => "http://public@splat.test/wren" }.merge(env)) do
      load Rails.root.join("config/initializers/sentry.rb").to_s
      setup_sentry_test { |config| config.background_worker_threads = 0 }
      # sentry-rails subscribes the breadcrumbs at boot, and only if Sentry has
      # started by then, so starting it later means taking that step here.
      Sentry::Railtie.instance.send(:inject_breadcrumbs_logger)
      yield
    end
  ensure
    Sentry::Rails::Breadcrumb::ActiveSupportLogger.detach if defined?(Sentry::Rails::Breadcrumb::ActiveSupportLogger)
    teardown_sentry_test
    Sentry.close
  end

  def with_env(vars)
    original = vars.keys.index_with { ENV[it] }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
