# frozen_string_literal: true

module Observ
  class PromptManager
    # Concern for comparing different versions of prompts.
    # Provides diff functionality to highlight changes between versions.
    module Comparison
      # ============================================
      # VERSION COMPARISON
      # ============================================

      # Compare two versions of a prompt
      # @param name [String] The prompt name
      # @param version_a [Integer] First version number
      # @param version_b [Integer] Second version number
      # @return [Hash] Hash with :from, :to, and :diff keys
      def compare_versions(name:, version_a:, version_b:)
        prompt_a = Prompt.find_by!(name: name, version: version_a)
        prompt_b = Prompt.find_by!(name: name, version: version_b)

        {
          from: prompt_a,
          to: prompt_b,
          diff: calculate_diff(prompt_a.prompt, prompt_b.prompt)
        }
      end

      private

      # ============================================
      # PRIVATE DIFF CALCULATION
      # ============================================

      # Calculate diff between two text strings
      # @param text_a [String] First text
      # @param text_b [String] Second text
      # @return [Hash] Hash with :added_lines, :removed_lines, and :changed keys
      def calculate_diff(text_a, text_b)
        # Simple line-by-line diff
        # In production, consider using 'diff-lcs' gem for better diffs
        {
          added_lines: text_b.lines - text_a.lines,
          removed_lines: text_a.lines - text_b.lines,
          changed: text_a != text_b
        }
      end
    end
  end
end
