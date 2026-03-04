require 'rails_helper'

RSpec.describe Todos::UpdateItemService do
  let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }
  let(:item) do
    create(:item, todo_list:, description: 'Original', completed: false,
                  external_id: '10', external_source_id: 'item-1')
  end

  describe '.call' do
    it 'updates item attributes' do
      result = described_class.call(
        item:,
        description: 'Updated',
        completed: true
      )

      expect(result).to eq item
      expect(item.reload.description).to eq 'Updated'
      expect(item.completed).to be true
    end

    context 'when item has external_id' do
      it 'does not change external_id or external_source_id' do
        described_class.call(item:, completed: true)

        item.reload
        expect(item.external_id).to eq '10'
        expect(item.external_source_id).to eq 'item-1'
      end
    end

    context 'when item has no external_id' do
      let(:local_item) { create(:item, todo_list:, description: 'Local', completed: false) }

      it 'updates attributes without touching sync metadata' do
        described_class.call(item: local_item, completed: true)

        local_item.reload
        expect(local_item.completed).to be true
        expect(local_item.external_id).to be_nil
        expect(local_item.external_source_id).to be_nil
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
