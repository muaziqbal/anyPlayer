# frozen_string_literal: true

class Search::ArtistsController < ApplicationController
  def index
    @artists = Artist.search(params[:query])
  end
end
