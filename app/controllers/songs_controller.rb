# frozen_string_literal: true

class SongsController < ApplicationController
  before_action :get_sort_options, only: [:index]

  def index
    records = Song.includes(:artist, :album)
      .filter_records(filter_params)
      .sort_records(*sort_params)

    @pagy, @songs = pagy(records)
  end

  private

  def filter_params
    params[:filter]&.slice(*Song::VALID_FILTERS)
  end

  def sort_params
    [params[:sort], params[:sort_direction]]
  end

  def get_sort_options
    @sort_options = Song.sort_options
  end
end
