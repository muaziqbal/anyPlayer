# frozen_string_literal: true

require "test_helper"

class AlbumTest < ActiveSupport::TestCase
  test "should not have same name album on an artist" do
    artists(:artist1).albums.create(name: "best")
    assert_not artists(:artist1).albums.build(name: "best").valid?
  end

  test "should have default title when name is empty" do
    assert_equal "Unknown Album", Album.create(name: nil).title
  end

  test "should order by tracknum for associated songs" do
    artist = artists(:artist1)
    album = artist.albums.create

    album.songs.create!(
      [
        {name: "test_song_1", file_path: "fake_path", file_path_hash: "fake_path_hash", md5_hash: "fake_md5", tracknum: 2, artist: artist},
        {name: "test_song_2", file_path: "fake_path", file_path_hash: "fake_path_hash", md5_hash: "fake_md5", tracknum: 3, artist: artist},
        {name: "test_song_3", file_path: "fake_path", file_path_hash: "fake_path_hash", md5_hash: "fake_md5", tracknum: 1, artist: artist}
      ]
    )

    assert_equal %w[test_song_3 test_song_1 test_song_2], album.songs.pluck(:name)
  end

  test "should filter by genre" do
    assert_equal Album.where(name: %w[album1 album2]).ids.sort, Album.filter_records(genre: "Rock").ids.sort
  end

  test "should filter by year" do
    assert_equal Album.where(name: %w[album2]).ids.sort, Album.filter_records(year: 1984).ids.sort
  end

  test "should filter by multiple attributes" do
    assert_equal Album.where(name: %w[album2]).ids.sort, Album.filter_records(genre: "Rock", year: 1984).ids.sort
  end

  test "should have valid filter constant" do
    assert_equal %w[year genre], Album::VALID_FILTERS
  end

  test "should not filter by invalid filter value" do
    assert_equal Album.all.ids.sort, Album.filter_records(invalid: "test").ids.sort
  end

  test "should sort by name" do
    assert_equal %w[album1 album2 album3 album4], Album.sort_records(:name).pluck(:name)
    assert_equal %w[album4 album3 album2 album1], Album.sort_records(:name, :desc).pluck(:name)
  end

  test "should sort by year" do
    assert_equal %w[album4 album3 album2 album1], Album.sort_records(:year).pluck(:name)
    assert_equal %w[album1 album2 album3 album4], Album.sort_records(:year, :desc).pluck(:name)
  end

  test "should sort by created_at" do
    assert_equal %w[album2 album1 album3 album4], Album.sort_records(:created_at).pluck(:name)
    assert_equal %w[album4 album3 album1 album2], Album.sort_records(:created_at, :desc).pluck(:name)
  end

  test "should sort by artist name" do
    assert_equal %w[album4 album1 album2 album3], Album.sort_records(:artist_name).pluck(:name)
    assert_equal %w[album3 album1 album2 album4], Album.sort_records(:artist_name, :desc).pluck(:name)
  end

  test "should sort by name by default" do
    assert_equal %w[album1 album2 album3 album4], Album.sort_records.pluck(:name)
  end

  test "should get sort options" do
    assert_equal %w[name year created_at artist_name], Album::SORT_OPTION.values
    assert_equal "name", Album::SORT_OPTION.default.name
    assert_equal "asc", Album::SORT_OPTION.default.direction
  end

  test "should use default sort when use invalid sort value" do
    assert_equal %w[album1 album2 album3 album4], Album.sort_records(:invalid).pluck(:name)
  end
end
