require 'rails_helper'

RSpec.describe ExternalTodoApi::PushSyncJob, type: :job do
  describe '#perform' do
    context 'when record exists' do
      let(:todo_list) { TodoList.create!(name: 'List', external_id: '1', external_source_id: 'src-1', synced: false) }

      it 'pushes update to API and sets synced' do
        stub_request(:patch, 'http://localhost:3001/todolists/1')
          .to_return(status: 200, body: { id: 1, name: 'List' }.to_json, headers: { 'Content-Type' => 'application/json' })

        described_class.perform_now('TodoList', todo_list.id, :update)

        expect(todo_list.reload.synced).to be true
      end

      it 'uses external_sync queue' do
        expect(described_class.new.queue_name).to eq 'external_sync'
      end
    end

    context 'when record is Item' do
      let(:todo_list) { TodoList.create!(name: 'List', external_id: '1', external_source_id: 'src-1', pending_sync_items_count: 1) }
      let(:item) do
        todo_list.items.create!(
          description: 'Item',
          completed: false,
          external_id: '10',
          external_source_id: 'item-1',
          synced: false
        )
      end

      it 'loads record via todo_list and calls PushSyncService' do
        stub_request(:patch, 'http://localhost:3001/todolists/1/todoitems/10')
          .to_return(status: 200, body: { id: 10, description: 'Item', completed: true }.to_json, headers: { 'Content-Type' => 'application/json' })

        described_class.perform_now('Item', item.id, :update)

        expect(item.reload.synced).to be true
      end
    end

    context 'when record does not exist' do
      it 'discards the job without retrying' do
        expect {
          described_class.perform_now('TodoList', 999_999, :update)
        }.not_to raise_error
      end
    end

    context 'when action is delete with phantom Item record' do
      let(:todo_list) { TodoList.create!(name: 'List', external_id: '1', external_source_id: 'src-1', pending_sync_items_count: 1) }

      before do
        stub_request(:delete, 'http://localhost:3001/todolists/1/todoitems/10').to_return(status: 204)
      end

      it 'decrements pending_sync_items_count on the real TodoList' do
        expect {
          described_class.perform_now(
            'Item', nil, 'delete',
            deleted_attrs: { external_id: '10', external_source_id: 'item-1', todo_list_id: todo_list.id }
          )
        }.to change { todo_list.reload.pending_sync_items_count }.from(1).to(0)
      end
    end
  end
end
