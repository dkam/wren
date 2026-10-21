class NamesController < ApplicationController
  before_action :set_list

  def create
    invalid = @list.add_names(params[:names])
    flash[:alert] = "Not names, so skipped: #{invalid.join(", ")}" if invalid.any?
    redirect_to list_path(@list)
  end

  def defaults
    @list.add_names(List::DEFAULT_NAMES.join(" "))
    redirect_to list_path(@list)
  end

  def destroy
    @list.names.where(value: params[:value]).delete_all
    redirect_to list_path(@list)
  end
end
