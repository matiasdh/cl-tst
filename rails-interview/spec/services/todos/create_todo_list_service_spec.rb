require 'rails_helper'

RSpec.describe Todos::CreateTodoListService do
  describe '.call' do
    it 'creates a todo list with the given name' do
      result = described_class.call(name: 'My List')

      expect(result).to be_a TodoList
      expect(result.persisted?).to be true
      expect(result.name).to eq 'My List'
    end

    it 'enqueues PushSyncJob with create action and the new todo list id' do
      result = nil
      expect {
        result = described_class.call(name: 'New List')
      }.to have_enqueued_job(ExternalTodoApi::PushSyncJob).with(
        'TodoList',
        kind_of(Integer),
        'create'
      )
      expect(result).to be_present
    end

    context 'when validation fails' do
      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          described_class.call(name: '')
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
