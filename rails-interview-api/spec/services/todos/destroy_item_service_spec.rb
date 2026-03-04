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
      it 'destroys the item' do
        expect {
          described_class.call(item:)
        }.to change(Item, :count).by(-1)
      end
    end

    context 'when item has no external_id' do
      let(:local_item) { create(:item, todo_list:, description: 'Local') }

      it 'destroys local-only items' do
        expect {
          described_class.call(item: local_item)
        }.to change { local_item.destroyed? }.from(false).to(true)
      end
    end
  end
end
