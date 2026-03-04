require 'rails_helper'

RSpec.describe TodoList, type: :model do
  subject { build(:todo_list) }

  describe 'associations' do
    it { is_expected.to have_many(:items).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:external_id).scoped_to(:external_source_id).allow_blank }
  end

  describe 'attributes' do
    it 'has a name' do
      expect(subject.name).to be_present
    end
  end

  describe '.with_associations' do
    it 'eager loads items' do
      todo_list = create(:todo_list)
      create(:item, todo_list:)

      list = TodoList.with_associations.find(todo_list.id)
      expect(list.association(:items)).to be_loaded
    end
  end
end
