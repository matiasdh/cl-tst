require 'rails_helper'

RSpec.describe Todos::UpdateTodoListService do
  let(:todo_list) do
    create(:todo_list, name: 'Original', external_id: '1', external_source_id: 'src-1')
  end

  describe '.call' do
    it 'updates todo_list attributes' do
      result = described_class.call(todo_list:, name: 'Updated')

      expect(result).to eq todo_list
      expect(todo_list.reload.name).to eq 'Updated'
    end

    context 'when todo_list has external_id' do
      it 'does not change external_id or external_source_id' do
        described_class.call(todo_list:, name: 'Updated')

        todo_list.reload
        expect(todo_list.external_id).to eq '1'
        expect(todo_list.external_source_id).to eq 'src-1'
      end
    end

    context 'when todo_list has no external_id' do
      let(:local_todo_list) { create(:todo_list, name: 'Local') }

      it 'only updates provided attributes' do
        described_class.call(todo_list: local_todo_list, name: 'Updated')

        expect(local_todo_list.reload.name).to eq 'Updated'
      end
    end
  end
end
