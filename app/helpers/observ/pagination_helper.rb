# frozen_string_literal: true

module Observ
  module PaginationHelper
    # Renders pagination controls with info
    # Usage: <%= observ_pagination(@collection) %>
    def observ_pagination(collection)
      return unless collection.respond_to?(:current_page)
      
      content_tag(:div, class: "observ-pagination") do
        safe_join([
          pagination_info(collection),
          pagination_links(collection)
        ])
      end
    end
    
    private
    
    def pagination_info(collection)
      return "" if collection.total_count.zero?
      
      from = collection.offset_value + 1
      to = [collection.offset_value + collection.limit_value, collection.total_count].min
      total = collection.total_count
      
      content_tag(:div, class: "observ-pagination__info") do
        "Showing #{from}-#{to} of #{total}"
      end
    end
    
    def pagination_links(collection)
      content_tag(:div, class: "observ-pagination__links") do
        paginate collection, theme: 'observ'
      end
    end
  end
end
