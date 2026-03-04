require 'rails_helper'

RSpec.describe ExternalTodoApi::ResyncNewItemsService do
  let(:base_url) { 'http://localhost:3001' }
  let(:service) { described_class.new }

  describe '#call' do
    context 'when a synced list has items without external_id' do
      let!(:todo_list) do
        TodoList.create!(
          name: 'My List',
          external_id: '1',
          external_source_id: 'src-1',
          synced: true,
          pending_sync_items_count: 1
        )
      end

      let!(:synced_item) do
        todo_list.items.create!(
          description: 'Existing item',
          completed: false,
          external_id: '10',
          external_source_id: 'src-1',
          synced: true
        )
      end

      let!(:new_item) do
        todo_list.items.create!(
          description: 'New item',
          completed: false,
          synced: false
        )
      end

      let(:recreate_response_body) do
        {
          id: 99,
          source_id: 'src-99',
          name: 'My List',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
          items: [
            { id: 50, source_id: 'src-99', description: 'Existing item', completed: false, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z' },
            { id: 51, source_id: 'src-99', description: 'New item', completed: false, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z' }
          ]
        }
      end

      before do
        stub_request(:delete, "#{base_url}/todolists/1").to_return(status: 204)
        stub_request(:post, "#{base_url}/todolists")
          .to_return(status: 201, body: recreate_response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'deletes the list remotely and recreates it' do
        service.call

        expect(a_request(:delete, "#{base_url}/todolists/1")).to have_been_made.once
        expect(a_request(:post, "#{base_url}/todolists")).to have_been_made.once
      end

      it 'updates the list with new external IDs' do
        service.call

        todo_list.reload
        expect(todo_list.external_id).to eq '99'
        expect(todo_list.external_source_id).to eq 'src-99'
        expect(todo_list.synced).to be true
        expect(todo_list.pending_sync_items_count).to eq 0
      end

      it 'updates all items with new external IDs' do
        service.call

        synced_item.reload
        expect(synced_item.external_id).to eq '50'
        expect(synced_item.external_source_id).to eq 'src-99'
        expect(synced_item.synced).to be true

        new_item.reload
        expect(new_item.external_id).to eq '51'
        expect(new_item.external_source_id).to eq 'src-99'
        expect(new_item.synced).to be true
      end
    end

    context 'when the remote list was already deleted (404 on delete)' do
      let!(:todo_list) do
        TodoList.create!(
          name: 'My List',
          external_id: '1',
          external_source_id: 'src-1',
          synced: true,
          pending_sync_items_count: 1
        )
      end

      let!(:synced_item) do
        todo_list.items.create!(
          description: 'Existing item',
          completed: false,
          external_id: '10',
          external_source_id: 'src-1',
          synced: true
        )
      end

      let!(:new_item) do
        todo_list.items.create!(
          description: 'New item',
          completed: false,
          synced: false
        )
      end

      let(:recreate_response_body) do
        {
          id: 99,
          source_id: 'src-99',
          name: 'My List',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
          items: [
            { id: 50, source_id: 'src-99', description: 'Existing item', completed: false, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z' },
            { id: 51, source_id: 'src-99', description: 'New item', completed: false, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z' }
          ]
        }
      end

      before do
        stub_request(:delete, "#{base_url}/todolists/1").to_return(status: 404, body: 'Not found')
        stub_request(:post, "#{base_url}/todolists")
          .to_return(status: 201, body: recreate_response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'still recreates the list remotely and updates local records' do
        service.call

        expect(a_request(:delete, "#{base_url}/todolists/1")).to have_been_made.once
        expect(a_request(:post, "#{base_url}/todolists")).to have_been_made.once

        todo_list.reload
        expect(todo_list.external_id).to eq '99'
        expect(todo_list.external_source_id).to eq 'src-99'
        expect(todo_list.synced).to be true
        expect(todo_list.pending_sync_items_count).to eq 0

        synced_item.reload
        expect(synced_item.external_id).to eq '50'
        expect(synced_item.external_source_id).to eq 'src-99'
        expect(synced_item.synced).to be true

        new_item.reload
        expect(new_item.external_id).to eq '51'
        expect(new_item.external_source_id).to eq 'src-99'
        expect(new_item.synced).to be true
      end
    end

    context 'when all items have external_id' do
      let!(:todo_list) do
        TodoList.create!(
          name: 'Fully Synced',
          external_id: '2',
          external_source_id: 'src-2',
          synced: true
        )
      end

      let!(:item) do
        todo_list.items.create!(
          description: 'Synced item',
          completed: false,
          external_id: '20',
          external_source_id: 'src-2',
          synced: true
        )
      end

      it 'does not call the external API' do
        service.call

        expect(a_request(:any, /todolists/)).not_to have_been_made
      end
    end

    context 'when list has no external_id (never synced)' do
      let!(:todo_list) { TodoList.create!(name: 'Local Only') }
      let!(:item) { todo_list.items.create!(description: 'Local item', completed: false) }

      it 'does not call the external API' do
        service.call

        expect(a_request(:any, /todolists/)).not_to have_been_made
      end
    end

    context 'when API fails for one list but not another' do
      let!(:failing_list) do
        TodoList.create!(
          name: 'Failing',
          external_id: '3',
          external_source_id: 'src-3',
          synced: true
        ).tap { |tl| tl.items.create!(description: 'New', completed: false) }
      end

      let!(:success_list) do
        TodoList.create!(
          name: 'Success',
          external_id: '4',
          external_source_id: 'src-4',
          synced: true
        ).tap { |tl| tl.items.create!(description: 'New', completed: false) }
      end

      let(:success_response_body) do
        {
          id: 100,
          source_id: 'src-100',
          name: 'Success',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
          items: [
            { id: 60, source_id: 'src-100', description: 'New', completed: false, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z' }
          ]
        }
      end

      before do
        stub_request(:delete, "#{base_url}/todolists/3").to_return(status: 500)
        stub_request(:delete, "#{base_url}/todolists/4").to_return(status: 204)
        stub_request(:post, "#{base_url}/todolists")
          .to_return(status: 201, body: success_response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'continues processing the second list after the first fails' do
        service.call

        expect(failing_list.reload.external_id).to eq '3'
        expect(success_list.reload.external_id).to eq '100'
      end
    end
  end
end
