module Observ
  module ApplicationHelper
    # Include helper modules to make them available across all views
    include Observ::DashboardHelper
    include Observ::ChatsHelper
  end
end
