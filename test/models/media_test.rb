# frozen_string_literal: true

require "test_helper"

class MediaTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    clear_media_data
    flush_redis

    Setting.update(media_path: Rails.root.join("test/fixtures/files"))
    Media.sync
  end

  test "should create all records in database when synced" do
    assert_equal 3, Artist.count
    assert_equal 4, Album.count
    assert_equal 9, Song.count
  end

  test "should create associations between artists and albums" do
    assert_equal Album.where(name: %w[album1 album2]).ids.sort, Artist.find_by(name: "artist1").albums.ids.sort
    assert_equal Album.where(name: "album3").ids.sort, Artist.find_by(name: "artist2").albums.ids.sort
    assert_equal Album.where(name: "album4").ids.sort, Artist.find_by(is_various: true).albums.ids.sort
  end

  test "should create associations between albums and songs" do
    album1_songs_ids = Song.where(name: %w[flac_sample m4a_sample]).ids.sort
    album2_songs_ids = Song.where(name: "mp3_sample").ids.sort
    album3_songs_ids = Song.where(name: %w[ogg_sample wav_sample opus_sample oga_sample wma_sample]).ids.sort
    album4_songs_ids = Song.where(name: %w[various_artists_sample]).ids.sort

    assert_equal album1_songs_ids, Album.find_by(name: "album1").songs.ids.sort
    assert_equal album2_songs_ids, Album.find_by(name: "album2").songs.ids.sort
    assert_equal album3_songs_ids, Album.find_by(name: "album3").songs.ids.sort
    assert_equal album4_songs_ids, Album.find_by(name: "album4").songs.ids.sort
  end

  test "should create associations between artists and songs" do
    artist1_songs_ids = Song.where(name: %w[flac_sample mp3_sample m4a_sample various_artists_sample]).ids.sort
    artist2_songs_ids = Song.where(name: %w[ogg_sample wav_sample opus_sample oga_sample wma_sample]).ids.sort

    assert_equal artist1_songs_ids, Artist.find_by(name: "artist1").songs.ids.sort
    assert_equal artist2_songs_ids, Artist.find_by(name: "artist2").songs.ids.sort
    assert_equal [], Artist.find_by(is_various: true).songs.ids.sort
  end

  test "should change associations when modify album info on file" do
    MediaFile.stub(:file_info, media_file_info_stub(file_fixture("artist1_album2.mp3"), album_name: "album1")) do
      Media.sync

      album1_songs_ids = Song.where(name: %w[flac_sample m4a_sample mp3_sample]).ids.sort

      assert_equal Album.where(name: "album1").ids.sort, Artist.find_by(name: "artist1").albums.ids.sort
      assert_equal album1_songs_ids, Album.find_by(name: "album1").songs.ids.sort
    end
  end

  test "should change associations when modify artist info on file" do
    MediaFile.stub(
      :file_info,
      media_file_info_stub(file_fixture("artist1_album2.mp3"), artist_name: "artist2", albumartist_name: "artist2")
    ) do
      Media.sync

      artist2_songs_ids = Song.where(
        name: %w[mp3_sample ogg_sample wav_sample opus_sample oga_sample wma_sample]
      ).ids.sort

      assert_equal Album.where(name: %w[album2 album3]).ids.sort, Artist.find_by(name: "artist2").albums.ids.sort
      assert_equal artist2_songs_ids, Artist.find_by(name: "artist2").songs.ids.sort
    end
  end

  test "should change song attribute when modify song info on file" do
    MediaFile.stub(:file_info, media_file_info_stub(file_fixture("artist1_album2.mp3"), tracknum: 2)) do
      assert_changes -> { Song.find_by(name: "mp3_sample").tracknum }, from: 1, to: 2 do
        Media.sync
      end
    end
  end

  test "should clear records on database when delete file" do
    create_tmp_dir(from: Setting.media_path) do |tmp_dir|
      Setting.update(media_path: tmp_dir)

      File.delete File.join(tmp_dir, "artist2_album3.ogg")
      File.delete File.join(tmp_dir, "artist2_album3.wav")
      File.delete File.join(tmp_dir, "artist2_album3.opus")
      File.delete File.join(tmp_dir, "artist2_album3.oga")
      File.delete File.join(tmp_dir, "artist2_album3.wma")

      Media.sync

      assert_nil Song.find_by(name: "ogg_sample")
      assert_nil Song.find_by(name: "wav_sample")
      assert_nil Song.find_by(name: "opus_sample")
      assert_nil Song.find_by(name: "oga_sample")
      assert_nil Song.find_by(name: "wma_sample")
      assert_nil Album.find_by(name: "album3")
      assert_nil Artist.find_by(name: "artist2")
    end
  end

  test "should get syncing status" do
    assert_not Media.syncing?
  end

  test "should change syncing status" do
    Media.syncing = true
    assert Media.syncing?
  end

  test "should always get same id" do
    assert_equal "TWVkaWE=", Media.instance.id
    assert_equal Media.instance.id, Media.instance.id
  end

  test "should broadcast media sync stream when set syncing status" do
    assert_broadcasts("media_sync", 1) do
      Media.syncing = true
    end
  end
end
