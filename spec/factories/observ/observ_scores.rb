# frozen_string_literal: true

FactoryBot.define do
  factory :observ_score, class: "Observ::Score" do
    association :dataset_run_item, factory: :observ_dataset_run_item
    trace { dataset_run_item.trace || association(:observ_trace) }
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
  end
end
