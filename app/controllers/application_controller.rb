# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend
  include SessionsHelper

  helper_method :native_app?, :need_transcode?, :render_flash, :mobile?

  before_action :find_current_session
  before_action :find_current_request_details
  before_action :require_login

  rescue_from BlackCandy::Forbidden do |error|
    respond_to do |format|
      format.json { render_json_error(error, :forbidden) }
      format.html { render template: "errors/forbidden", layout: "plain", status: :forbidden }
    end
  end

  rescue_from BlackCandy::InvalidCredential do |error|
    respond_to do |format|
      format.json { render_json_error(error, :unauthorized) }
      format.html { redirect_to new_session_path }
    end
  end

  rescue_from BlackCandy::DuplicatePlaylistSong do |error|
    respond_to do |format|
      format.json { render_json_error(error, :bad_request) }
    end
  end

  rescue_from ActiveRecord::RecordNotFound do |error|
    respond_to do |format|
      format.json { render_json_error(OpenStruct.new(type: "RecordNotFound", message: error.message), :not_found) }
      format.html { render template: "errors/not_found", layout: "plain", status: :not_found }
    end
  end

  rescue_from ActionController::InvalidAuthenticityToken do
    logout
  end

  def need_transcode?(song)
    song_format = song.format

    return true unless song_format.in?(Stream::WEB_SUPPORTED_FORMATS)
    return true if browser.safari? && !song_format.in?(Stream::SAFARI_SUPPORTED_FORMATS)
    return true if ios_app? && !song_format.in?(Stream::IOS_SUPPORTED_FORMATS)
    return true if android_app? && !song_format.in?(Stream::ANDROID_SUPPORTED_FORMATS)

    Setting.allow_transcode_lossless? ? song.lossless? : false
  end

  def flash_errors_message(object, now: false)
    errors_message = object.errors.full_messages.join(". ")

    if now
      flash.now[:error] = errors_message
    else
      flash[:error] = errors_message
    end
  end

  def native_app?
    ios_app? || android_app?
  end

  def redirect_back_with_referer_params(fallback_location:)
    if params[:referer_url].present?
      redirect_to params[:referer_url]
    else
      redirect_back_or_to(fallback_location)
    end
  end

  def render_flash(type: :success, message: "")
    flash[type] = message unless message.blank?
    turbo_stream.update "turbo-flash", partial: "shared/flash"
  end

  def mobile?
    browser.device.mobile?
  end

  private

  def find_current_session
    Current.session = Session.find_by(id: cookies.signed[:session_id])
  end

  def require_login
    return if logged_in?

    if native_app?
      head :unauthorized
    else
      redirect_to new_session_path
    end
  end

  def require_admin
    raise BlackCandy::Forbidden if BlackCandy::Config.demo_mode? || !is_admin?
  end

  def ios_app?
    Current.user_agent.to_s.match?(/Black Candy iOS/)
  end

  def android_app?
    Current.user_agent.to_s.match?(/Black Candy Android/)
  end

  def render_json_error(error, status)
    render json: {type: error.type, message: error.message}, status: status
  end

  def send_local_file(file_path, format, nginx_headers: {})
    if BlackCandy::Config.nginx_sendfile?
      nginx_headers.each { |name, value| response.headers[name] = value }
      send_file file_path

      return
    end

    # Use Rack::Files to support HTTP range without nginx. see https://github.com/rails/rails/issues/32193
    Rack::Files.new(nil).serving(request, file_path).tap do |(status, headers, body)|
      self.status = status
      self.response_body = body

      headers.each { |name, value| response.headers[name] = value }

      response.headers["Content-Type"] = Mime[format]
      response.headers["Content-Disposition"] = "attachment"
    end
  end

  def find_current_request_details
    Current.ip_address = request.ip
    Current.user_agent = request.user_agent
  end
end
