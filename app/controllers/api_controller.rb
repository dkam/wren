# What agents call. JSON in or form params in, JSON out; no CSRF, since the
# list's token is the only key there is. It comes as a bearer token in the
# Authorization header, as the key parameter, or in the path; the first two
# keep it out of the request line, and so out of logs.
class ApiController < ActionController::API
  # No CSP nonce: it lives in the session, and JSON has no use for one.
  before_action { request.content_security_policy_nonce_generator = nil }

  # Ahead of the lookup, so a wrong key counts toward the limit as a right one does.
  rate_limit to: 60, within: 1.minute, store: ApplicationController::RATE_LIMITS, by: ApplicationController::RATE_LIMITED_BY
  before_action { @list = List.find_by!(token: (bearer || params[:token] || params[:key]).to_s) }

  rescue_from(ActiveRecord::RecordNotFound) { render json: { error: "no such list" }, status: :not_found }
  rescue_from(ActiveRecord::RecordInvalid) { |e| render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content }

  def show
    render json: @list
  end

  def claim
    return render(json: { error: "session is required" }, status: :bad_request) if params[:session].blank?

    if (claim = @list.claim(session: params[:session], note: params[:note], host: params[:host], exclude: params[:exclude]))
      render json: claim
    else
      render json: { error: "every name is taken" }, status: :conflict
    end
  end

  def reserve
    if (claim = @list.reserve(name: params[:name].to_s, note: params[:note], host: params[:host]))
      render json: claim
    else
      render json: { error: "#{params[:name]} is taken" }, status: :conflict
    end
  end

  def release
    if @list.release(params[:name].to_s)
      head :no_content
    else
      render json: { error: "#{params[:name]} is not claimed" }, status: :not_found
    end
  end

  private
    def bearer = ActionController::HttpAuthentication::Token.token_and_options(request)&.first
end
