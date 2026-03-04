require 'rails_helper'

RSpec.describe PushSyncable do
  let(:test_class) do
    Class.new do
      include PushSyncable

      def enqueue_update(record)
        enqueue_push_sync(record, :update)
      end

      def enqueue_delete(record, todo_list_id: nil)
        enqueue_push_sync_delete(record, todo_list_id:)
      end
    end
  end

  let(:instance) { test_class.new }

  describe '#enqueue_push_sync' do
    context 'when record has external_id' do
      let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }
      let(:item) do
        create(:item, todo_list:, external_id: '10', external_source_id: 'item-1')
      end

      it 'enqueues PushSyncJob with record class, id and action' do
        expect {
          instance.enqueue_update(item)
        }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
          'Item',
          item.id,
          'update'
        )
      end
    end

    context 'when record has no external_id' do
      let(:item) { create(:item, todo_list: create(:todo_list)) }

      it 'does not enqueue PushSyncJob' do
        expect {
          instance.enqueue_update(item)
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end
    end
  end

  describe '#enqueue_push_sync_delete' do
    context 'when record has external_id' do
      let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }
      let(:item) do
        create(:item, todo_list:, external_id: '10', external_source_id: 'item-1')
      end

      it 'enqueues PushSyncJob with delete action and deleted_attrs' do
        expect {
          instance.enqueue_delete(item, todo_list_id: todo_list.id)
        }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
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

    context 'when record has external_id but no todo_list_id' do
      let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }

      it 'enqueues with deleted_attrs without todo_list_id' do
        expect {
          instance.enqueue_delete(todo_list)
        }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
          'TodoList',
          nil,
          'delete',
          deleted_attrs: {
            external_id: todo_list.external_id,
            external_source_id: todo_list.external_source_id
          }
        )
      end
    end

    context 'when record has no external_id' do
      let(:item) { create(:item, todo_list: create(:todo_list)) }

      it 'does not enqueue PushSyncJob' do
        expect {
          instance.enqueue_delete(item, todo_list_id: item.todo_list_id)
        }.not_to have_enqueued_job(ExternalTodoApi::PushSyncJob)
      end
    end
  end
end
