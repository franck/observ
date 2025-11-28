module Observ
  class ApplicationController < ActionController::Base
    layout "observ/application"

    # Engine-specific configuration
    protect_from_forgery with: :exception
  end
end
