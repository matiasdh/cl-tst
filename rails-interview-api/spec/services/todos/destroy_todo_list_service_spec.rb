require 'rails_helper'

RSpec.describe Todos::DestroyTodoListService do
  let!(:todo_list) do
    create(:todo_list, name: 'To delete', external_id: '1', external_source_id: 'src-1')
  end

  describe '.call' do
    it 'destroys the todo_list' do
      expect {
        described_class.call(todo_list:)
      }.to change(TodoList, :count).by(-1)
    end

    context 'when todo_list has external_id' do
      it 'allows destroying external records locally' do
        expect {
          described_class.call(todo_list:)
        }.to change(TodoList, :count).by(-1)
      end
    end

    context 'when todo_list has no external_id' do
      let(:local_todo_list) { create(:todo_list, name: 'Local') }

      it 'destroys local-only records as well' do
        expect {
          described_class.call(todo_list: local_todo_list)
        }.to change { local_todo_list.destroyed? }.from(false).to(true)
      end
    end
  end
end
