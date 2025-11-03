module Observ
  class ApplicationController < ::ApplicationController
    layout "observ/application"

    # Engine-specific configuration
    protect_from_forgery with: :exception
  end
end
