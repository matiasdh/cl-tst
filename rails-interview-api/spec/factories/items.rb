FactoryBot.define do
  factory :item do
    sequence(:description) { |n| "Task #{n}" }
    completed { false }
    todo_list
  end
end
