# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# Parameters are filtered by name, but a list's key is also the first segment
# of its pages' paths: /<key>, /<key>.json, /<key>/names. So it is taken out of
# the request line and of redirects too. Thruster, in front, would log the path
# as well; the Dockerfile turns its request log off.
Rails.application.config.filter_redirect << %r{\Ahttps?://[^/]+/[A-Za-z0-9]{12}\b}

class KeyMaskingLogger < Rails::Rack::Logger
  private
    # Started GET "/[FILTERED]/names" for 127.0.0.1 at ...
    def started_request_message(request)
      super.sub(%r{"/[A-Za-z0-9]{12}(?=[/."?])}, '"/[FILTERED]')
    end
end
Rails.application.config.middleware.swap Rails::Rack::Logger, KeyMaskingLogger, Rails.application.config.log_tags
