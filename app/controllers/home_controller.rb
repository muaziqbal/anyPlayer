# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @recently_added_albums = Album.includes(:artist).order(created_at: :desc).limit(10)
    @recently_played_albums = Current.user.recently_played_albums
  end
end
