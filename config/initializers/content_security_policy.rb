# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Wren loads nothing from anywhere else: its scripts, styles and icons are its
# own. The inline scripts (the importmap) and Turbo's progress bar style carry
# the nonce, from csp_meta_tag in the layout.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # The nonce is kept in the session, so it is the same on every page Turbo
  # swaps in under the first page's policy, and it is there on a first visit,
  # which the session's id, Rails's suggestion, is not. ApiController asks for
  # none, so an agent's call is never given a cookie.
  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
