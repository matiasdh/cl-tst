require 'rails_helper'

RSpec.describe ExternalTodoApi::PullSyncProcessJob, type: :job do
  let(:payload) do
    [
      {
        'id' => 1,
        'source_id' => 'src-1',
        'name' => 'List 1',
        'created_at' => '2024-01-01T00:00:00Z',
        'updated_at' => '2024-01-01T00:00:00Z',
        'items' => [
          {
            'id' => 10,
            'source_id' => 'item-1',
            'description' => 'Item A',
            'completed' => false,
            'created_at' => '2024-01-01T00:00:00Z',
            'updated_at' => '2024-01-01T00:00:00Z'
          }
        ]
      }
    ]
  end

  describe '#perform' do
    context 'when payload exists in cache' do
      before do
        allow(Rails.cache).to receive(:read).with(ExternalTodoApi::PullSyncFetchJob::PAYLOAD_CACHE_KEY)
          .and_return(payload)
      end

      it 'processes payload and creates TodoList and Item' do
        expect {
          described_class.perform_now
        }.to change(TodoList, :count).by(1).and change(Item, :count).by(1)

        todo_list = TodoList.find_by(external_source_id: 'src-1', external_id: '1')
        expect(todo_list.name).to eq 'List 1'
        expect(todo_list.synced).to be true

        item = Item.find_by(external_source_id: 'item-1', external_id: '10')
        expect(item.description).to eq 'Item A'
      end
    end

    context 'when payload is expired or missing' do
      before do
        allow(Rails.cache).to receive(:read).with(ExternalTodoApi::PullSyncFetchJob::PAYLOAD_CACHE_KEY)
          .and_return(nil)
      end

      it 'does not raise and does not create records' do
        expect {
          described_class.perform_now
        }.not_to raise_error

        expect(TodoList.count).to eq 0
      end
    end
  end
end
