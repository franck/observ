FactoryBot.define do
  factory :observ_trace, class: 'Observ::Trace' do
    trace_id { SecureRandom.uuid }
    association :observ_session, factory: :observ_session
    name { 'chat.ask' }
    start_time { Time.current }
    input { 'Test input message' }
    metadata { { phase: 'test' } }
    tags { [] }

    trait :finalized do
      end_time { start_time + 2.seconds }
      output { 'Test output response' }
    end

    trait :with_metrics do
      total_cost { 0.01 }
      total_tokens { 100 }
    end

    trait :with_observations do
      after(:create) do |trace|
        create(:observ_generation, trace: trace)
        create(:observ_span, trace: trace)
      end
    end
  end
end
