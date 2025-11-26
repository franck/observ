# frozen_string_literal: true

FactoryBot.define do
  factory :observ_review_item, class: "Observ::ReviewItem" do
    association :reviewable, factory: :observ_session
    status { :pending }
    priority { :normal }
    reason { "high_cost" }
    reason_details { { cost: 0.15, threshold: 0.10 } }

    trait :for_session do
      association :reviewable, factory: :observ_session
    end

    trait :for_trace do
      association :reviewable, factory: :observ_trace
    end

    trait :pending do
      status { :pending }
    end

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      completed_at { Time.current }
      completed_by { "test_user" }
    end

    trait :skipped do
      status { :skipped }
      completed_at { Time.current }
      completed_by { "test_user" }
    end

    trait :normal_priority do
      priority { :normal }
    end

    trait :high_priority do
      priority { :high }
    end

    trait :critical_priority do
      priority { :critical }
    end

    trait :error_detected do
      reason { "error_detected" }
      priority { :critical }
      reason_details { { error: "Something went wrong" } }
    end

    trait :high_latency do
      reason { "high_latency" }
      priority { :normal }
      reason_details { { latency_ms: 35000, threshold: 30000 } }
    end

    trait :no_output do
      reason { "no_output" }
      priority { :high }
      reason_details { {} }
    end

    trait :random_sample do
      reason { "random_sample" }
      priority { :normal }
      reason_details { {} }
    end
  end
end
