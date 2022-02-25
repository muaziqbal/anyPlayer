# frozen_string_literal: true

class Media
  include Singleton
  include Turbo::Broadcastable
  extend ActiveModel::Naming

  class << self
    def sync_all(dir = Setting.media_path)
      sync(:all, MediaFile.file_paths(dir))
    ensure
      instance.broadcast_render_to "media_sync", partial: "media_syncing/syncing", locals: {syncing: false}
    end

    def sync(type, file_paths = [])
      self.syncing = true

      return if file_paths.blank?

      case type
      when :all
        file_hashes = add_files(file_paths)
        clean_up(file_hashes)
      when :added
        add_files(file_paths)
      when :removed
        remove_files(file_paths)
      when :modified
        remove_files(file_paths)
        add_files(file_paths)
      end

      fetch_external_metadata unless type == :removed
    ensure
      self.syncing = false
    end

    def syncing?
      Rails.cache.fetch("media_syncing") { false }
    end

    def syncing=(is_syncing)
      return if is_syncing == syncing?
      Rails.cache.write("media_syncing", is_syncing, expires_in: 1.hour)
    end

    private

    def add_files(file_paths)
      file_paths.map do |file_path|
        file_info = MediaFile.file_info(file_path)
        file_info[:md5_hash] if attach(file_info)
      rescue
        next
      end.compact
    end

    def remove_files(file_paths)
      file_path_hashes = file_paths.map { |file_path| MediaFile.get_md5_hash(file_path) }
      Song.where(file_path_hash: file_path_hashes).destroy_all

      clean_up
    end

    def attach(file_info)
      artist = Artist.find_or_create_by!(name: file_info[:artist_name] || Artist::UNKNOWN_NAME)
      various_artist = Artist.find_or_create_by!(various: true) if various_artist?(file_info)

      album = Album.find_or_initialize_by(
        artist: various_artist || artist,
        name: file_info[:album_name] || Album::UNKNOWN_NAME
      )

      album.update!(album_info(file_info))

      unless album.has_cover_image?
        album.cover_image.attach(file_info[:image]) if file_info[:image].present?
      end

      song = Song.find_or_initialize_by(md5_hash: file_info[:md5_hash])
      song.update!(song_info(file_info).merge(album: album, artist: artist))
    end

    def song_info(file_info)
      file_info.slice(:name, :tracknum, :discnum, :duration, :file_path, :file_path_hash, :bit_depth).compact
    end

    def album_info(file_info)
      file_info.slice(:year, :genre).compact
    end

    def various_artist?(file_info)
      albumartist = file_info[:albumartist_name]
      albumartist.present? && (albumartist.casecmp("various artists").zero? || albumartist != file_info[:artist_name])
    end

    def clean_up(file_hashes = [])
      Song.where.not(md5_hash: file_hashes).destroy_all if file_hashes.present?

      # Clean up no content albums and artist.
      Album.where.missing(:songs).destroy_all
      Artist.where.missing(:songs, :albums).destroy_all
    end

    def fetch_external_metadata
      return unless Setting.discogs_token.present?

      jobs = []

      Artist.lack_metadata.find_each do |artist|
        jobs << AttachCoverImageFromDiscogsJob.new(artist)
      end

      Album.lack_metadata.find_each do |album|
        jobs << AttachCoverImageFromDiscogsJob.new(album)
      end

      ActiveJob.perform_all_later(jobs)
    end
  end
end
