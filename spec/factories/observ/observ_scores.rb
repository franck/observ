# frozen_string_literal: true

FactoryBot.define do
  factory :observ_score, class: "Observ::Score" do
    association :scoreable, factory: :observ_dataset_run_item
    name { "accuracy" }
    value { 1.0 }
    data_type { :numeric }
    source { :programmatic }

    trait :passing do
      value { 1.0 }
    end

    trait :failing do
      value { 0.0 }
    end

    trait :boolean do
      data_type { :boolean }
    end

    trait :manual do
      source { :manual }
      data_type { :boolean }
    end

    trait :programmatic do
      source { :programmatic }
    end

    trait :with_comment do
      comment { "Evaluation comment" }
    end

    trait :for_session do
      association :scoreable, factory: :observ_session
    end

    trait :for_trace do
      association :scoreable, factory: :observ_trace
    end

    trait :for_dataset_run_item do
      association :scoreable, factory: :observ_dataset_run_item
    end
  end
end
