class ListsController < ApplicationController
  before_action :set_list, only: %i[show update]

  def new
  end

  def create
    list = List.create!(title: params[:title].presence)
    redirect_to list_path(list)
  end

  def show
    respond_to do |format|
      format.html { @claims = @list.claims.index_by(&:name) }
      format.json { render json: { title: @list.title, names: @list.names.pluck(:value), claims: @list.claims } }
    end
  end

  def update
    @list.update!(title: params[:title].presence)
    redirect_to list_path(@list)
  end
end
