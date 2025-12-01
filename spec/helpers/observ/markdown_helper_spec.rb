require 'rails_helper'

RSpec.describe Observ::MarkdownHelper, type: :helper do
  describe '#render_markdown' do
    it 'returns empty string for nil content' do
      expect(helper.render_markdown(nil)).to eq("")
    end

    it 'returns empty string for blank content' do
      expect(helper.render_markdown("")).to eq("")
      expect(helper.render_markdown("   ")).to eq("")
    end

    it 'renders plain text as paragraph' do
      result = helper.render_markdown("Hello world")

      expect(result).to include("<p>")
      expect(result).to include("Hello world")
    end

    it 'renders bold text' do
      result = helper.render_markdown("**bold text**")

      expect(result).to include("<strong>bold text</strong>")
    end

    it 'renders italic text' do
      result = helper.render_markdown("*italic text*")

      expect(result).to include("<em>italic text</em>")
    end

    it 'renders inline code' do
      result = helper.render_markdown("`code`")

      expect(result).to include("<code>code</code>")
    end

    it 'renders fenced code blocks' do
      result = helper.render_markdown("```ruby\nputs 'hello'\n```")

      expect(result).to include("<pre>")
      expect(result).to include("<code")
      expect(result).to include("puts")
    end

    it 'renders unordered lists' do
      result = helper.render_markdown("- item 1\n- item 2")

      expect(result).to include("<ul>")
      expect(result).to include("<li>")
      expect(result).to include("item 1")
      expect(result).to include("item 2")
    end

    it 'renders ordered lists' do
      result = helper.render_markdown("1. first\n2. second")

      expect(result).to include("<ol>")
      expect(result).to include("<li>")
      expect(result).to include("first")
      expect(result).to include("second")
    end

    it 'renders headers' do
      result = helper.render_markdown("# Header 1\n## Header 2")

      expect(result).to include("<h1>Header 1</h1>")
      expect(result).to include("<h2>Header 2</h2>")
    end

    it 'renders blockquotes' do
      result = helper.render_markdown("> quoted text")

      expect(result).to include("<blockquote>")
      expect(result).to include("quoted text")
    end

    it 'renders links with target blank' do
      result = helper.render_markdown("[link](https://example.com)")

      expect(result).to include('<a href="https://example.com"')
      expect(result).to include('target="_blank"')
      expect(result).to include('rel="noopener noreferrer"')
    end

    it 'auto-links URLs' do
      result = helper.render_markdown("Check https://example.com for more")

      expect(result).to include('<a href="https://example.com"')
    end

    it 'renders tables' do
      markdown = "| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1   | Cell 2   |"
      result = helper.render_markdown(markdown)

      expect(result).to include("<table>")
      expect(result).to include("<th>")
      expect(result).to include("<td>")
    end

    it 'renders strikethrough' do
      result = helper.render_markdown("~~deleted~~")

      expect(result).to include("<del>deleted</del>")
    end

    it 'renders hard line breaks' do
      result = helper.render_markdown("line 1\nline 2")

      expect(result).to include("<br>")
    end

    it 'returns html_safe string' do
      result = helper.render_markdown("**bold**")

      expect(result).to be_html_safe
    end
  end
end
