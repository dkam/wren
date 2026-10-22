class ListsController < ApplicationController
  before_action :set_list, only: %i[show update]
  rate_limit to: 10, within: 1.hour, only: :create, store: RATE_LIMITS, by: RATE_LIMITED_BY

  def new
  end

  def create
    list = List.create!(title: params[:title].presence)
    redirect_to list_path(list)
  end

  # Opens a list from its token, or from its whole address pasted in.
  def find
    if (list = List.find_by(token: params[:key].to_s.strip.delete_suffix("/")[/#{List::TOKEN}\z/o]))
      redirect_to list_path(list)
    else
      redirect_to root_path, alert: "No such key"
    end
  end

  def show
    # The page's address is the key, so keep it out of search engines.
    response.set_header("X-Robots-Tag", "noindex")
    respond_to do |format|
      format.html { @claims = @list.claims.index_by(&:name) }
      format.json { render json: @list }
    end
  end

  def update
    @list.update!(params.permit(:title))
    redirect_to list_path(@list)
  end
end
