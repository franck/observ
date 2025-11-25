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

    trait :with_invalid_temperature do
      config { { temperature: 3.0 } }
    end

    trait :with_invalid_max_tokens do
      config { { max_tokens: 0 } }
    end

    trait :with_invalid_top_p do
      config { { top_p: 1.5 } }
    end

    trait :with_invalid_type do
      config { { temperature: "high" } }
    end

    trait :with_valid_advanced_config do
      config {
        {
          model: "gpt-4o",
          temperature: 0.8,
          max_tokens: 2000,
          top_p: 0.95,
          frequency_penalty: 0.5,
          presence_penalty: 0.3,
          stop_sequences: [ "STOP", "END" ]
        }
      }
    end

    # Mustache templating traits
    trait :with_loop do
      prompt { "Items in cart:\n{{#items}}\n- {{name}}: ${{price}}\n{{/items}}\nTotal: ${{total}}" }
    end

    trait :with_conditional do
      prompt { "Hello {{name}}!{{#premium}} You have premium access.{{/premium}}{{^premium}} Upgrade to premium for more features.{{/premium}}" }
    end

    trait :with_nested_context do
      prompt { "Order for {{customer.name}}:\n{{#items}}\n- {{name}} ({{quantity}}x)\n{{/items}}" }
    end

    trait :with_inverted_section do
      prompt { "{{#items}}You have {{count}} items.{{/items}}{{^items}}Your cart is empty.{{/items}}" }
    end

    trait :with_html_content do
      prompt { "Content: {{{html_content}}}" }
    end

    trait :with_comment do
      prompt { "{{! This is a comment }}Hello {{name}}!" }
    end
  end
end
