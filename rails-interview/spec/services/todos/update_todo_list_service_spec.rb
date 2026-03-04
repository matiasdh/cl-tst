require 'rails_helper'

RSpec.describe Todos::UpdateTodoListService do
  let(:todo_list) do
    create(:todo_list, name: 'Original', external_id: '1', external_source_id: 'src-1', synced: true)
  end

  describe '.call' do
    it 'updates todo_list attributes and sets synced to false' do
      result = described_class.call(todo_list:, name: 'Updated')

      expect(result).to eq todo_list
      expect(todo_list.reload.name).to eq 'Updated'
      expect(todo_list.synced).to be false
    end

    context 'when todo_list has external_id' do
      it 'enqueues PushSyncJob for update' do
        expect {
          described_class.call(todo_list:, name: 'Updated')
        }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
          'TodoList',
          todo_list.id,
          'update'
        )
      end
    end

    context 'when todo_list has no external_id' do
      let(:local_todo_list) { create(:todo_list, name: 'Local') }

      it 'does not enqueue PushSyncJob' do
        expect {
          described_class.call(todo_list: local_todo_list, name: 'Updated')
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end
    end
  end
end
