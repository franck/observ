FactoryBot.define do
  factory :observ_prompt, class: 'Observ::Prompt' do
    sequence(:name) { |n| "test-prompt-#{n}" }
    prompt { "You are a {{role}}. Today is {{date}}." }
    version { 1 }
    state { :draft }
    config { { model: 'gpt-4o', temperature: 0.7 } }
    commit_message { "Initial version" }
    created_by { "test@example.com" }

    trait :draft do
      state { :draft }
    end

    trait :production do
      state { :production }
      after(:create) do |prompt|
        # Ensure no other production version exists
        Observ::Prompt.where(name: prompt.name, state: :production)
                      .where.not(id: prompt.id)
                      .update_all(state: :archived)
      end
    end

    trait :archived do
      state { :archived }
    end

    trait :with_variables do
      prompt { "Hello {{name}}, you are {{age}} years old and work as a {{job}}." }
    end

    trait :simple do
      prompt { "You are a helpful assistant." }
    end

    trait :version_2 do
      version { 2 }
    end

    trait :version_3 do
      version { 3 }
    end
  end
end
