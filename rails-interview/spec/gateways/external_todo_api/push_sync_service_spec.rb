require 'rails_helper'

RSpec.describe ExternalTodoApi::PushSyncService do
  let(:base_url) { 'http://localhost:3001' }
  let(:service) { described_class.new }

  describe '#call' do
    context 'with TodoList' do
      context 'when action is :create' do
        let(:todo_list) do
          TodoList.create!(name: 'New List').tap do |tl|
            tl.items.create!(description: 'First item', completed: false)
          end
        end

        let(:response_body) do
          {
            id: 99,
            source_id: 'src-99',
            name: 'New List',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z',
            items: [
              { id: 10, source_id: 'src-99', description: 'First item', completed: false, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z' }
            ]
          }
        end

        before do
          stub_request(:post, "#{base_url}/todolists")
            .to_return(status: 201, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'sends POST with items and updates record and items with external_id and synced' do
          service.call(todo_list, :create)

          expect(todo_list.reload.external_id).to eq '99'
          expect(todo_list.external_source_id).to eq 'src-99'
          expect(todo_list.synced).to be true

          item = todo_list.items.first
          expect(item.external_id).to eq '10'
          expect(item.external_source_id).to eq 'src-99'
          expect(item.synced).to be true
        end
      end

      context 'when action is :update' do
        let(:todo_list) do
          TodoList.create!(name: 'List', external_id: '1', external_source_id: 'src-1', synced: false)
        end

        before do
          stub_request(:patch, "#{base_url}/todolists/1")
            .with(body: { name: 'Updated Name' }.to_json, headers: { 'Content-Type' => 'application/json' })
            .to_return(status: 200, body: { id: 1, name: 'Updated Name' }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'sends PATCH and sets synced to true' do
          todo_list.update!(name: 'Updated Name')
          service.call(todo_list, :update)

          expect(todo_list.reload.synced).to be true
        end
      end

      context 'when action is :update without external_id' do
        let(:todo_list) { TodoList.create!(name: 'Local Only', synced: false) }

        it 'does not call the API' do
          service.call(todo_list, :update)

          expect(todo_list.reload.synced).to be false
        end
      end

      context 'when action is :delete' do
        let(:todo_list) do
          TodoList.create!(name: 'List', external_id: '1', external_source_id: 'src-1')
        end

        before do
          stub_request(:delete, "#{base_url}/todolists/1").to_return(status: 204)
        end

        it 'sends DELETE to the external API' do
          service.call(todo_list, :delete)

          expect(a_request(:delete, "#{base_url}/todolists/1")).to have_been_made.once
        end
      end
    end

    context 'with Item' do
      let(:todo_list) do
        TodoList.create!(name: 'List', external_id: '1', external_source_id: 'src-1', pending_sync_items_count: 1)
      end
      let(:item) do
        todo_list.items.create!(
          description: 'Item',
          completed: false,
          external_id: '10',
          external_source_id: 'item-1',
          synced: false
        )
      end

      context 'when action is :create' do
        it 'does nothing (API does not support)' do
          expect { service.call(item, :create) }.not_to raise_error
        end
      end

      context 'when action is :update' do
        before do
          stub_request(:patch, "#{base_url}/todolists/1/todoitems/10")
            .with(body: { description: 'Item', completed: true }.to_json, headers: { 'Content-Type' => 'application/json' })
            .to_return(
              status: 200,
              body: { id: 10, description: 'Item', completed: true }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'sends PATCH, sets synced and decrements pending_sync_items_count' do
          item.update!(completed: true)
          service.call(item, :update)

          expect(item.reload.synced).to be true
          expect(todo_list.reload.pending_sync_items_count).to eq 0
        end
      end

      context 'when action is :delete' do
        before do
          stub_request(:delete, "#{base_url}/todolists/1/todoitems/10").to_return(status: 204)
        end

        it 'sends DELETE and decrements pending_sync_items_count' do
          service.call(item, :delete)

          expect(todo_list.reload.pending_sync_items_count).to eq 0
        end
      end

      context 'when action is :update without external_id' do
        let(:item) do
          todo_list.items.create!(description: 'Local Item', completed: false, synced: false)
        end

        it 'does not call the API' do
          service.call(item, :update)

          expect(item.reload.synced).to be false
        end
      end
    end
  end
end
