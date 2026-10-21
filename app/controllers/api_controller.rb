# What agents call. JSON in or form params in, JSON out; no CSRF, since the
# list's token in the URL is the only key there is.
class ApiController < ActionController::API
  before_action { @list = List.find_by!(token: params[:token]) }

  rescue_from(ActiveRecord::RecordNotFound) { render json: { error: "no such list" }, status: :not_found }
  rescue_from(ActiveRecord::RecordInvalid) { |e| render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content }

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
end
