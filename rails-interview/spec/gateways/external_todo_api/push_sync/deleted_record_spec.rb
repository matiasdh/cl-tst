require 'rails_helper'

RSpec.describe ExternalTodoApi::PushSync::DeletedRecord do
  describe '.build' do
    context 'when todo_list_id is present' do
      let(:todo_list) { create(:todo_list, external_id: '1', external_source_id: 'src-1') }

      it 'loads the TodoList and sets it on the record' do
        record = described_class.build(
          external_id: '10',
          external_source_id: 'item-1',
          todo_list_id: todo_list.id
        )

        expect(record.external_id).to eq '10'
        expect(record.external_source_id).to eq 'item-1'
        expect(record.todo_list).to eq todo_list
      end
    end

    context 'when todo_list_id is absent' do
      it 'sets todo_list to nil' do
        record = described_class.build(
          external_id: '1',
          external_source_id: 'src-1'
        )

        expect(record.external_id).to eq '1'
        expect(record.external_source_id).to eq 'src-1'
        expect(record.todo_list).to be_nil
      end
    end

    context 'when attrs use string keys' do
      let(:todo_list) { create(:todo_list, external_id: '1') }

      it 'symbolizes keys and builds correctly' do
        record = described_class.build(
          'external_id' => '10',
          'external_source_id' => 'item-1',
          'todo_list_id' => todo_list.id
        )

        expect(record.external_id).to eq '10'
        expect(record.todo_list).to eq todo_list
      end
    end
  end
end
