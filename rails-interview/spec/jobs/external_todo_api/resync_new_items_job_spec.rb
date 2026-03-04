require 'rails_helper'

RSpec.describe ExternalTodoApi::ResyncNewItemsJob, type: :job do
  describe '#perform' do
    it 'delegates to ResyncNewItemsService' do
      service = instance_double(ExternalTodoApi::ResyncNewItemsService)
      allow(ExternalTodoApi::ResyncNewItemsService).to receive(:new).and_return(service)
      allow(service).to receive(:call)

      described_class.new.perform

      expect(service).to have_received(:call)
    end

    it 'is enqueued in the external_sync queue' do
      expect(described_class.new.queue_name).to eq 'external_sync'
    end
  end
end
