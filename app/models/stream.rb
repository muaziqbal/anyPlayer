# frozen_string_literal: true

class Stream
  TRANSCODING_FORMATS = %w[flac wav oga wma].freeze
  TRANSCODE_FORMAT = "mp3"
  TRANSCODE_CACHE_DIRECTORY = Rails.root.join("tmp/cache/media_file")

  def initialize(song)
    @song = song
  end

  def file_path
    @song.file_path
  end

  def file_duration
    @song.length
  end

  def format
    MediaFile.format(@song.file_path)
  end

  def need_transcode?
    format.in? TRANSCODING_FORMATS
  end

  def transcode_cache_file_path
    file_directory = "#{TRANSCODE_CACHE_DIRECTORY}/#{@song.id}"
    FileUtils.mkdir_p(file_directory)

    "#{file_directory}/#{Base64.urlsafe_encode64(@song.md5_hash)}_#{Setting.transcode_bitrate}.#{TRANSCODE_FORMAT}"
  end

  # let instance of Stream can respond to each() method.
  # So the download can be streamed, instead of read whole data into memory.
  def each
    command = ["ffmpeg", "-i", file_path, "-map", "0:0", "-v", "0", "-ab", "#{Setting.transcode_bitrate}k", "-f", TRANSCODE_FORMAT, "-"]
    # need add error raise when can not found ffmpeg command.
    IO.popen(command) do |io|
      while (line = io.gets)
        yield line
      end
    end
  end
end
