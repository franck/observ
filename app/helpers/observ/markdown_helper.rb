require "redcarpet"

module Observ
  module MarkdownHelper
    def render_markdown(content)
      return "" if content.blank?

      markdown_renderer.render(content).html_safe
    end

    private

    def markdown_renderer
      @markdown_renderer ||= Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(
          hard_wrap: true,
          link_attributes: { target: "_blank", rel: "noopener noreferrer" }
        ),
        autolink: true,
        fenced_code_blocks: true,
        tables: true,
        strikethrough: true,
        no_intra_emphasis: true,
        highlight: true,
        quote: true
      )
    end
  end
end
