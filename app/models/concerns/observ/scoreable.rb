# frozen_string_literal: true

module Observ
  module Scoreable
    extend ActiveSupport::Concern

    included do
      has_many :scores, as: :scoreable, class_name: "Observ::Score", dependent: :destroy
    end

    # Find a score by name, optionally filtered by source
    # Returns the most recent score if multiple exist
    def score_for(name, source: nil)
      scope = scores.where(name: name)
      scope = scope.where(source: source) if source
      scope.order(created_at: :desc).first
    end

    # Returns true if any scores exist for this record
    def scored?
      scores.exists?
    end

    # Returns the manual score (name="manual", source="manual")
    def manual_score
      score_for("manual", source: :manual)
    end

    # Returns a hash of score names to their average values
    def score_summary
      scores.group(:name).average(:value).transform_values { |v| v.round(4) }
    end
  end
end
