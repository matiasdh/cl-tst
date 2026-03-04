require 'rails_helper'

RSpec.describe Todos::CreateTodoListService do
  describe '.call' do
    it 'creates a todo list with the given name' do
      result = described_class.call(name: 'My List')

      expect(result).to be_a TodoList
      expect(result.persisted?).to be true
      expect(result.name).to eq 'My List'
    end

    context 'when validation fails' do
      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          described_class.call(name: '')
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
