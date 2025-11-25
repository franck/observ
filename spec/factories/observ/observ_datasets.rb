# frozen_string_literal: true

FactoryBot.define do
  factory :observ_dataset, class: "Observ::Dataset" do
    sequence(:name) { |n| "test_dataset_#{n}" }
    description { "A test dataset for evaluation" }
    agent_class { "DummyAgent" }
    metadata { {} }

    trait :with_description do
      description { "Detailed description of the test dataset" }
    end

    trait :with_metadata do
      metadata { { category: "testing", priority: "high" } }
    end

    trait :with_items do
      transient do
        items_count { 3 }
      end

      after(:create) do |dataset, evaluator|
        create_list(:observ_dataset_item, evaluator.items_count, dataset: dataset)
      end
    end

    trait :with_runs do
      transient do
        runs_count { 2 }
      end

      after(:create) do |dataset, evaluator|
        create_list(:observ_dataset_run, evaluator.runs_count, dataset: dataset)
      end
    end
  end

  factory :observ_dataset_item, class: "Observ::DatasetItem" do
    association :dataset, factory: :observ_dataset
    status { :active }
    input { { text: "What is the capital of France?" } }
    expected_output { { answer: "Paris" } }
    metadata { {} }

    trait :archived do
      status { :archived }
    end

    trait :with_string_input do
      input { "Simple string input" }
      expected_output { "Simple string output" }
    end

    trait :with_metadata do
      metadata { { category: "geography", difficulty: "easy" } }
    end

    trait :from_trace do
      association :source_trace, factory: :observ_trace
    end
  end

  factory :observ_dataset_run, class: "Observ::DatasetRun" do
    association :dataset, factory: :observ_dataset
    sequence(:name) { |n| "run_v#{n}" }
    description { "Test run" }
    status { :pending }
    metadata { {} }
    total_items { 0 }
    completed_items { 0 }
    failed_items { 0 }
    total_cost { 0 }
    total_tokens { 0 }

    trait :running do
      status { :running }
      total_items { 5 }
      completed_items { 2 }
    end

    trait :completed do
      status { :completed }
      total_items { 5 }
      completed_items { 4 }
      failed_items { 1 }
      total_cost { 0.0025 }
      total_tokens { 500 }
    end

    trait :failed do
      status { :failed }
      total_items { 5 }
      completed_items { 2 }
      failed_items { 3 }
    end

    trait :with_metadata do
      metadata { { model: "gpt-4", temperature: 0.7 } }
    end

    trait :with_run_items do
      transient do
        run_items_count { 3 }
      end

      after(:create) do |run, evaluator|
        evaluator.run_items_count.times do
          item = create(:observ_dataset_item, dataset: run.dataset)
          create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)
        end
        run.update!(total_items: run.run_items.count)
      end
    end
  end

  factory :observ_dataset_run_item, class: "Observ::DatasetRunItem" do
    association :dataset_run, factory: :observ_dataset_run
    association :dataset_item, factory: :observ_dataset_item

    trait :succeeded do
      association :trace, factory: :observ_trace
      error { nil }
    end

    trait :failed do
      trace { nil }
      error { "Agent execution failed: Connection timeout" }
    end

    trait :with_observation do
      association :trace, factory: :observ_trace
      association :observation, factory: :observ_observation
    end
  end
end
