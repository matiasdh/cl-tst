require 'rails_helper'

RSpec.describe Todos::DestroyItemService do
  let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }
  let!(:item) do
    create(:item, todo_list:, description: 'To delete',
                  external_id: '10', external_source_id: 'item-1')
  end

  describe '.call' do
    it 'destroys the item' do
      expect {
        described_class.call(item:)
      }.to change(Item, :count).by(-1)
    end

    context 'when item has external_id' do
      it 'increments pending_sync_items_count and enqueues PushSyncJob with delete' do
        expect {
          described_class.call(item:)
        }.to change { todo_list.reload.pending_sync_items_count }.by(1)
           .and have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
             'Item',
             nil,
             'delete',
             deleted_attrs: {
               external_id: '10',
               external_source_id: 'item-1',
               todo_list_id: todo_list.id
             }
           )
      end
    end

    context 'when item has no external_id' do
      let(:local_item) { create(:item, todo_list:, description: 'Local') }

      it 'does not increment pending_sync_items_count' do
        expect {
          described_class.call(item: local_item)
        }.not_to change { todo_list.reload.pending_sync_items_count }
      end

      it 'does not enqueue PushSyncJob' do
        expect {
          described_class.call(item: local_item)
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end
    end
  end
end
