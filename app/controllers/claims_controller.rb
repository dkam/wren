# Releasing a name from the page, for an agent that is gone without saying so.
class ClaimsController < ApplicationController
  before_action :set_list

  def destroy
    @list.release(params[:name])
    redirect_to list_path(@list)
  end
end
