FactoryBot.define do
  factory :observ_session, class: 'Observ::Session' do
    session_id { SecureRandom.uuid }
    user_id { "user_#{SecureRandom.hex(4)}" }
    start_time { Time.current }
    metadata { { agent_type: 'test', chat_id: 1 } }

    trait :with_metadata do
      metadata do
        {
          agent_type: 'standard',
          chat_id: 123,
          phase: 'testing'
        }
      end
    end

    trait :finalized do
      end_time { start_time + 30.seconds }
    end

    trait :with_metrics do
      total_traces_count { 5 }
      total_llm_calls_count { 10 }
      total_tokens { 1000 }
      total_cost { 0.05 }
      total_llm_duration_ms { 5000 }
    end
  end
end
