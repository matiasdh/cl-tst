require 'rails_helper'

RSpec.describe Todos::UpdateItemService do
  let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }
  let(:item) do
    create(:item, todo_list:, description: 'Original', completed: false,
                  external_id: '10', external_source_id: 'item-1', synced: true)
  end

  describe '.call' do
    it 'updates item attributes and sets synced to false' do
      result = described_class.call(
        item:,
        description: 'Updated',
        completed: true
      )

      expect(result).to eq item
      expect(item.reload.description).to eq 'Updated'
      expect(item.completed).to be true
      expect(item.synced).to be false
    end

    context 'when item has external_id' do
      it 'increments pending_sync_items_count and enqueues PushSyncJob' do
        expect {
          described_class.call(item:, completed: true)
        }.to change { todo_list.reload.pending_sync_items_count }.by(1)
           .and have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
             'Item',
             item.id,
             'update'
           )
      end
    end

    context 'when item has no external_id' do
      let(:local_item) { create(:item, todo_list:, description: 'Local', completed: false) }

      it 'does not increment pending_sync_items_count' do
        expect {
          described_class.call(item: local_item, completed: true)
        }.not_to change { todo_list.reload.pending_sync_items_count }
      end

      it 'does not enqueue PushSyncJob' do
        expect {
          described_class.call(item: local_item, completed: true)
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end
    end

    context 'when only description is provided' do
      it 'updates only description' do
        described_class.call(item:, description: 'New description')

        expect(item.reload.description).to eq 'New description'
        expect(item.completed).to be false
      end
    end

    context 'when only completed is provided' do
      it 'updates only completed' do
        described_class.call(item:, completed: true)

        expect(item.reload.description).to eq 'Original'
        expect(item.completed).to be true
      end
    end
  end
end
