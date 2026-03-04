require 'rails_helper'

RSpec.describe ItemsBulkUpdateJob, type: :job do
  let(:todo_list) { create(:todo_list) }
  let(:task_id) { SecureRandom.uuid }

  describe '#perform' do
    context 'when all: true' do
      let!(:item1) { create(:item, todo_list:, completed: false) }
      let!(:item2) { create(:item, todo_list:, completed: false) }
      let!(:other_todo_list) { create(:todo_list) }
      let!(:other_item) { create(:item, todo_list: other_todo_list, completed: false) }

      it 'updates all items in the todo list to completed and synced false' do
        expect {
          described_class.perform_now(todo_list.id, task_id, item_ids: nil, all: true)
        }.to have_broadcasted_to("bulk_update_#{task_id}").with(status: 'completed')

        expect(item1.reload.completed).to be true
        expect(item1.synced).to be false
        expect(item2.reload.completed).to be true
        expect(item2.synced).to be false
        expect(other_item.reload.completed).to be false
      end
    end

    context 'when given specific item_ids' do
      let!(:item1) { create(:item, todo_list:, completed: false) }
      let!(:item2) { create(:item, todo_list:, completed: false) }
      let!(:item3) { create(:item, todo_list:, completed: false) }

      it 'updates only the specified items to completed' do
        expect {
          described_class.perform_now(
            todo_list.id,
            task_id,
            item_ids: [ item1.id, item3.id ],
            all: false
          )
        }.to have_broadcasted_to("bulk_update_#{task_id}").with(status: 'completed')

        expect(item1.reload.completed).to be true
        expect(item3.reload.completed).to be true
        expect(item2.reload.completed).to be false
      end
    end

    context 'when given no item_ids and all: false' do
      let!(:item1) { create(:item, todo_list:, completed: false) }

      it 'updates no items and broadcasts completion' do
        expect {
          described_class.perform_now(todo_list.id, task_id, item_ids: nil, all: false)
        }.to have_broadcasted_to("bulk_update_#{task_id}").with(status: 'completed')

        expect(item1.reload.completed).to be false
      end
    end

    context 'push sync' do
      let!(:synced_item1) do
        create(:item, todo_list:, completed: false,
               external_id: '10', external_source_id: 'src-1', synced: true)
      end
      let!(:synced_item2) do
        create(:item, todo_list:, completed: false,
               external_id: '20', external_source_id: 'src-2', synced: true)
      end
      let!(:local_item) do
        create(:item, todo_list:, completed: false, synced: true)
      end

      it 'enqueues PushSyncJob for items with external_id' do
        expect {
          described_class.perform_now(todo_list.id, task_id, all: true)
        }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).exactly(2).times

        expect(ExternalTodoApi::PushSyncJob).to have_been_enqueued.with('Item', synced_item1.id, 'update')
        expect(ExternalTodoApi::PushSyncJob).to have_been_enqueued.with('Item', synced_item2.id, 'update')
      end

      it 'increments pending_sync_items_count only for syncable items' do
        expect {
          described_class.perform_now(todo_list.id, task_id, all: true)
        }.to change { todo_list.reload.pending_sync_items_count }.by(2)
      end

      it 'marks all items as synced: false' do
        described_class.perform_now(todo_list.id, task_id, all: true)

        expect(synced_item1.reload.synced).to be false
        expect(synced_item2.reload.synced).to be false
        expect(local_item.reload.synced).to be false
      end

      it 'does not enqueue PushSyncJob for items without external_id' do
        local_only = create(:item, todo_list:, completed: false)

        expect {
          described_class.perform_now(
            todo_list.id, task_id,
            item_ids: [ local_only.id ],
            all: false
          )
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end

      it 'does not increment pending_sync_items_count when no syncable items' do
        local_only = create(:item, todo_list:, completed: false)

        expect {
          described_class.perform_now(
            todo_list.id, task_id,
            item_ids: [ local_only.id ],
            all: false
          )
        }.not_to change { todo_list.reload.pending_sync_items_count }
      end
    end
  end
end
