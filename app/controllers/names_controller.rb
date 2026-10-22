class NamesController < ApplicationController
  # Ahead of the lookup, so a wrong key counts toward the limit as a right one
  # does. Only a right one is then told why on its page.
  rate_limit to: 60, within: 1.minute, store: RATE_LIMITS, by: RATE_LIMITED_BY,
    with: -> { set_list; refuse "Too many changes in a minute. Wait a little, and try again.", status: :too_many_requests }
  before_action :set_list

  def create
    invalid = @list.add_names(params[:names])
    show_names alert: ("Not names, so skipped: #{invalid.join(", ")}" if invalid.any?)
  end

  def destroy
    @list.names.where(value: params[:value]).delete_all
    show_names
  end

  private
    # With Turbo, redraws the box of names in place; without, the whole page.
    def show_names(alert: nil)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("chosen", partial: "lists/chosen", locals: { list: @list, claims: @list.claims.index_by(&:name) }),
            turbo_stream.update("flash", partial: "lists/flash", locals: { alert: })
          ]
        end
        format.html { redirect_to list_path(@list), alert: }
      end
    end
end
