require 'rails_helper'

RSpec.describe ExternalTodoApi::PullSyncFetchJob, type: :job do
  let(:base_url) { 'http://localhost:3001' }
  let(:api_response) do
    [
      {
        id: 1,
        source_id: 'src-1',
        name: 'List 1',
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        items: []
      }
    ]
  end

  before do
    stub_request(:get, "#{base_url}/todolists")
      .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#perform' do
    it 'fetches from API and enqueues ProcessJob' do
      expect {
        described_class.perform_now
      }.to have_enqueued_job(ExternalTodoApi::PullSyncProcessJob)
    end

    it 'skips API call and enqueues ProcessJob when payload already in cache (retry path)' do
      allow(Rails.cache).to receive(:read).with(ExternalTodoApi::PullSyncFetchJob::PAYLOAD_CACHE_KEY)
        .and_return(api_response)

      expect(ExternalTodoApi::Client).not_to receive(:new)
      expect {
        described_class.perform_now
      }.to have_enqueued_job(ExternalTodoApi::PullSyncProcessJob)
    end
  end
end
