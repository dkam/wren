class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Counts for rate limits. In memory, so they are per process and start over
  # on a restart, which is close enough for one small box.
  RATE_LIMITS = ActiveSupport::Cache::MemoryStore.new

  # Whom a count is for: an IPv4 address, or an IPv6 /64, since anyone with
  # IPv6 has that many addresses to spread their requests across.
  RATE_LIMITED_BY = -> { IPAddr.new(request.remote_ip).native.then { it.ipv6? ? it.mask(64) : it }.to_s }

  rescue_from(ActiveRecord::RecordInvalid) { |e| refuse e.record.errors.full_messages.to_sentence }

  private
    # Says why on the list's page: in place when Turbo asked, or else by going
    # back to the page with the message.
    def refuse(message, status: :unprocessable_content)
      if @list && request.format.turbo_stream?
        render turbo_stream: turbo_stream.update("flash", partial: "lists/flash", locals: { alert: message }), status:
      else
        redirect_to(@list ? list_path(@list) : root_path, alert: message)
      end
    end

    def set_list
      @list = List.find_by!(token: params[:token])
    end
end
