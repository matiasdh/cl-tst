require 'rails_helper'

RSpec.describe Item, type: :model do
  subject { build(:item) }

  describe 'associations' do
    it { is_expected.to belong_to(:todo_list) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_uniqueness_of(:external_id).scoped_to(:external_source_id).allow_blank }

    it 'validates completed is a boolean' do
      item = build(:item, completed: nil)
      expect(item).not_to be_valid
      expect(item.errors[:completed]).to be_present
    end
  end

  describe 'defaults' do
    it 'defaults completed to false' do
      expect(Item.new.completed).to be false
    end
  end

  describe '.syncable' do
    let(:todo_list) { create(:todo_list) }
    let!(:synced_item) { create(:item, todo_list:, external_id: '10', external_source_id: 'src-1') }
    let!(:local_item) { create(:item, todo_list:, external_id: nil) }
    let!(:empty_external_id_item) { create(:item, todo_list:, external_id: '') }

    it 'returns only items with a present external_id' do
      expect(Item.syncable).to contain_exactly(synced_item)
    end
  end
end
