FactoryBot.define do
  factory :todo_list do
    sequence(:name) { |n| "Todo List #{n}" }
  end
end
