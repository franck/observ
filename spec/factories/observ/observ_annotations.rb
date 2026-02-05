FactoryBot.define do
  factory :observ_annotation, class: 'Observ::Annotation' do
    association :annotatable, factory: :observ_trace
    content { "Test annotation content" }
    annotator { "test_user" }
    tags { [] }

    trait :with_tags do
      tags { ["important", "review"] }
    end
  end
end
