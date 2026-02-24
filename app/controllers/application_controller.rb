# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authenticatable
  include LocaleSettable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActionPolicy::Unauthorized do |_ex|
    flash[:alert] = t("flash.unauthorized")
    redirect_back_or_to(root_path)
  end
end
