require 'rails_helper'

RSpec.describe ExternalTodoApi::PullSyncService do
  let(:lists) do
    body = [
      {
        id: 1,
        source_id: 'src-1',
        name: 'List 1',
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        items: [
          {
            id: 10,
            source_id: 'item-1',
            description: 'Item A',
            completed: false,
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z'
          }
        ]
      }
    ]
    ExternalTodoApi::Parser.parse_todo_lists(body)
  end

  describe '#call' do
    it 'creates TodoList and Item with correct attributes' do
      result = described_class.new.call(lists)

      expect(result).to be true

      todo_list = TodoList.find_by(external_source_id: 'src-1', external_id: '1')
      expect(todo_list).to be_present
      expect(todo_list.name).to eq 'List 1'
      expect(todo_list.synced).to be true

      item = Item.find_by(external_source_id: 'item-1', external_id: '10')
      expect(item).to be_present
      expect(item.description).to eq 'Item A'
      expect(item.completed).to be false
      expect(item.synced).to be true
    end

    it 'updates existing records on second call' do
      described_class.new.call(lists)
      lists_updated = ExternalTodoApi::Parser.parse_todo_lists([
        {
          id: 1,
          source_id: 'src-1',
          name: 'List 1 Updated',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-02T00:00:00Z',
          items: [
            {
              id: 10,
              source_id: 'item-1',
              description: 'Item A Updated',
              completed: true,
              created_at: '2024-01-01T00:00:00Z',
              updated_at: '2024-01-02T00:00:00Z'
            }
          ]
        }
      ])

      result = described_class.new.call(lists_updated)

      expect(result).to be true

      todo_list = TodoList.find_by(external_source_id: 'src-1', external_id: '1')
      expect(todo_list.name).to eq 'List 1 Updated'

      item = Item.find_by(external_source_id: 'item-1', external_id: '10')
      expect(item.description).to eq 'Item A Updated'
      expect(item.completed).to be true
    end

    context 'with empty lists' do
      it 'returns true' do
        result = described_class.new.call([])

        expect(result).to be true
      end
    end

    context 'when local record has synced false' do
      it 'skips update to preserve local changes' do
        described_class.new.call(lists)

        todo_list = TodoList.find_by(external_source_id: 'src-1', external_id: '1')
        todo_list.update!(name: 'Local Override', synced: false)

        lists_external = ExternalTodoApi::Parser.parse_todo_lists([
          {
            id: 1,
            source_id: 'src-1',
            name: 'External Override',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-02T00:00:00Z',
            items: []
          }
        ])

        described_class.new.call(lists_external)

        expect(todo_list.reload.name).to eq 'Local Override'
      end
    end

    context 'when an item references an unknown list' do
      let(:lists_with_unknown_item) do
        ExternalTodoApi::Parser.parse_todo_lists([
          {
            id: 99,
            source_id: 'unknown-src',
            name: 'Ghost List',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z',
            items: [
              {
                id: 1,
                source_id: 'orphan-item',
                description: 'Orphan',
                completed: false,
                created_at: '2024-01-01T00:00:00Z',
                updated_at: '2024-01-01T00:00:00Z'
              }
            ]
          }
        ])
      end

      it 'skips items whose todo_list is not found in the lookup' do
        # Force the lookup to return empty (simulate a failed upsert leaving no DB record)
        allow_any_instance_of(described_class).to receive(:lookup_todo_list_ids).and_return({})

        expect {
          described_class.new.call(lists_with_unknown_item)
        }.not_to raise_error

        expect(Item.count).to eq 0
      end
    end
  end
end
