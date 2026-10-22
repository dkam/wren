# frozen_string_literal: true

# Error tracking over the Sentry protocol, pointed at Splat. Nothing here is
# Splat's own: the DSN decides where events go, so hosted Sentry works too.
#
# SENTRY_DSN is the whole switch. Without it there is no init, and every
# Sentry call in the app does nothing, which is how development and test stay
# offline without a Rails.env check.
return if ENV["SENTRY_DSN"].blank?

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = Rails.env

  # The release and the commit it was built from, the way SemVer writes build
  # metadata: "0.1.0+a1b2c3d". config/version.rb says why they are two things.
  config.release = "#{Wren::VERSION}+#{Rails.application.config.x.revision}"

  # Leaves out request bodies, query strings, cookies and IPs. The key goes in
  # as a body field or a query parameter, so this keeps it out of those.
  config.send_default_pii = false
  config.breadcrumbs_logger = [ :active_support_logger ]

  # Splat drops release health, so there is no point sending it every minute.
  config.auto_session_tracking = false

  # Performance monitoring, off unless asked for, and never for the health
  # check compose makes every ten seconds.
  traces_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.0).to_f
  config.traces_sampler = lambda do |context|
    next 0.0 if context.dig(:transaction_context, :name).to_s.start_with?("/up")

    # Honour an upstream decision when a trace arrives already sampled.
    parent = context[:parent_sampled]
    next (parent ? 1.0 : 0.0) unless parent.nil?

    traces_rate
  end

  # A list's key is the whole of its credential, and the first segment of the
  # path of every page: /<key>, /<key>.json, /<key>/names. Sentry sends the
  # path whatever the PII setting says: in the URL, in the Referer of anything
  # done on the page, as the transaction's name and in the breadcrumbs, whose
  # paths and redirects (/find answers with one to /<key>) carry it. So the
  # keys found there are filtered out of everything the event carries, the
  # message and the exception's included.
  key_in_path = %r{\A(?:[a-z]+://[^/]+)?/([A-Za-z0-9]{12})(?=[/.?#]|\z)}
  filter = lambda do |value, keys|
    case value
    when String then keys.reduce(value) { |string, key| string.gsub(key, "[Filtered]") }
    when Hash then value.transform_values { filter.(it, keys) }
    when Array then value.map { filter.(it, keys) }
    else value
    end
  end

  without_keys = lambda do |event, _hint|
    request, crumbs = event.request, event.breadcrumbs&.members.to_a
    paths = [ request&.url, request&.headers&.dig("Referer"), event.transaction, *crumbs.flat_map { it.data.try(:values) } ]
    keys = paths.filter_map { it.to_s[key_in_path, 1] }.uniq
    next event if keys.empty?

    if request
      request.url = filter.(request.url, keys)
      request.headers = filter.(request.headers, keys)
    end
    crumbs.each do |crumb|
      crumb.message = filter.(crumb.message, keys)
      crumb.data = filter.(crumb.data, keys)
    end
    event.try(:exception)&.values&.each { it.value = filter.(it.value, keys) }
    event.spans = filter.(event.spans, keys) if event.respond_to?(:spans)
    event.transaction = filter.(event.transaction, keys)
    event.message = filter.(event.message, keys)
    event.extra, event.tags, event.contexts = filter.([ event.extra, event.tags, event.contexts ], keys)
    event
  end
  config.before_send = without_keys
  config.before_send_transaction = without_keys
end
