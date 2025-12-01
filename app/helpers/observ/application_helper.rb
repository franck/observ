module Observ
  module ApplicationHelper
    # Include helper modules to make them available across all views
    include Observ::DashboardHelper
    include Observ::ChatsHelper
    include Observ::PaginationHelper
    include Observ::DatasetsHelper
    include Observ::ReviewsHelper
    include Observ::MarkdownHelper
  end
end
