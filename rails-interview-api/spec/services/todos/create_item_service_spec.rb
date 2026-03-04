require 'rails_helper'

RSpec.describe Todos::CreateItemService do
  let(:todo_list) { create(:todo_list) }

  describe '.call' do
    it 'creates an item with description and completed' do
      result = described_class.call(
        todo_list:,
        description: 'Buy milk',
        completed: true
      )

      expect(result).to be_a Item
      expect(result.persisted?).to be true
      expect(result.description).to eq 'Buy milk'
      expect(result.completed).to be true
      expect(result.todo_list).to eq todo_list
    end

    it 'defaults completed to false when not provided' do
      result = described_class.call(todo_list:, description: 'Task')

      expect(result.completed).to be false
    end

    it 'treats completed "true" as true' do
      result = described_class.call(
        todo_list:,
        description: 'Task',
        completed: 'true'
      )

      expect(result.completed).to be true
    end

    context 'when validation fails' do
      it 'raises when description is blank' do
        expect {
          described_class.call(todo_list:, description: '')
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
