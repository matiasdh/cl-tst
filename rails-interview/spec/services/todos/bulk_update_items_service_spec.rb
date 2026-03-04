require 'rails_helper'

RSpec.describe Todos::BulkUpdateItemsService do
  let(:todo_list) { create(:todo_list) }

  describe '.call' do
    it 'enqueues ItemsBulkUpdateJob and returns a task_id' do
      task_id = nil

      expect {
        task_id = described_class.call(todo_list:, item_ids: [ 1, 2 ], all: false)
      }.to have_enqueued_job(ItemsBulkUpdateJob)

      expect(task_id).to be_present
      expect(task_id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'passes all: true to the job when requested' do
      expect {
        described_class.call(todo_list:, item_ids: [], all: true)
      }.to have_enqueued_job(ItemsBulkUpdateJob).with(
        todo_list.id,
        kind_of(String),
        item_ids: [],
        all: true
      )
    end

    it 'passes specific item_ids to the job' do
      expect {
        described_class.call(todo_list:, item_ids: [ 10, 20 ], all: false)
      }.to have_enqueued_job(ItemsBulkUpdateJob).with(
        todo_list.id,
        kind_of(String),
        item_ids: [ 10, 20 ],
        all: false
      )
    end
  end
end
