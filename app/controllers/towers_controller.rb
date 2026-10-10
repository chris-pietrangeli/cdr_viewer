class TowersController < ApplicationController
  def index
    @towers = Tower.order(:code).includes(:import)
  end
end
