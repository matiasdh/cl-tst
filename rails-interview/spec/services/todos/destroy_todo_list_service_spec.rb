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
      it 'enqueues PushSyncJob with delete and deleted_attrs' do
        expect {
          described_class.call(todo_list:)
        }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
          'TodoList',
          nil,
          'delete',
          deleted_attrs: {
            external_id: '1',
            external_source_id: 'src-1'
          }
        )
      end
    end

    context 'when todo_list has no external_id' do
      let(:local_todo_list) { create(:todo_list, name: 'Local') }

      it 'does not enqueue PushSyncJob' do
        expect {
          described_class.call(todo_list: local_todo_list)
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end
    end
  end
end
