require "rails_helper"

RSpec.describe "Api::TodoLists::Items", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:todo_list) { create(:todo_list) }
  let(:base_path) { "/api/todolists/#{todo_list.id}/todos" }

  describe "GET index" do
    let!(:item) { create(:item, todo_list: todo_list, description: "Buy milk") }

    it "returns 200 and JSON array of items for the todo_list" do
      get base_path, as: :json

      expect(response).to have_http_status(:ok)
      parsed = response.parsed_body
      expect(parsed).to be_an(Array)
      expect(parsed.length).to eq(1)
      expect(parsed.first).to match("id" => item.id, "description" => "Buy milk", "completed" => false)
    end

    it "returns 404 when todo_list does not exist" do
      get "/api/todolists/invalid_id/todos", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST create" do
    it "creates item with valid description" do
      expect {
        post base_path, params: { description: "New task" }, as: :json
      }.to change(Item, :count).by(1)
    end

    it "returns 201 and JSON with id, description, completed" do
      post base_path, params: { description: "New task" }, as: :json

      expect(response).to have_http_status(:created)
      parsed = response.parsed_body
      expect(parsed).to include("id", "description" => "New task", "completed" => false)
    end

    it "returns 422 when description is blank" do
      post base_path, params: { description: "" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      parsed = response.parsed_body
      expect(parsed).to have_key("errors")
    end

    it "returns 404 when todo_list does not exist" do
      post "/api/todolists/invalid_id/todos", params: { description: "Task" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "creates item with completed as true" do
      post base_path, params: { description: "Task", completed: true }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["completed"]).to be true
    end
  end

  describe "PATCH update" do
    let(:item) { create(:item, todo_list: todo_list, description: "Original", completed: false) }

    it "updates description and completed" do
      patch "#{base_path}/#{item.id}", params: { description: "Updated", completed: true }, as: :json

      expect(response).to have_http_status(:ok)
      parsed = response.parsed_body
      expect(parsed).to match("id" => item.id, "description" => "Updated", "completed" => true)
    end

    it "returns 422 when description is blank" do
      patch "#{base_path}/#{item.id}", params: { description: "" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when item does not exist" do
      patch "#{base_path}/invalid_id", params: { description: "Updated" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context "when item does not belong to todo_list" do
      let(:other_todo_list) { create(:todo_list) }
      let(:other_item) { create(:item, todo_list: other_todo_list) }

      it "returns 404" do
        patch "/api/todolists/#{todo_list.id}/todos/#{other_item.id}", params: { description: "Updated" }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when item has no external_id (local only)" do
      let(:local_item) { create(:item, todo_list: todo_list, description: "Local", completed: false) }

      it "does not increment pending_sync_items_count" do
        expect {
          patch "#{base_path}/#{local_item.id}", params: { completed: true }, as: :json
        }.not_to change { todo_list.reload.pending_sync_items_count }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "DELETE destroy" do
    let!(:item_to_delete) { create(:item, todo_list: todo_list) }

    it "deletes item and returns 204" do
      expect {
        delete "#{base_path}/#{item_to_delete.id}", as: :json
      }.to change(Item, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 when item does not exist" do
      delete "#{base_path}/invalid_id", as: :json

      expect(response).to have_http_status(:not_found)
    end

    context "when item does not belong to todo_list" do
      let(:other_todo_list) { create(:todo_list) }
      let(:other_item) { create(:item, todo_list: other_todo_list) }

      it "returns 404" do
        delete "/api/todolists/#{todo_list.id}/todos/#{other_item.id}", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH bulk_update" do
    let!(:item1) { create(:item, todo_list: todo_list, completed: false) }
    let!(:item2) { create(:item, todo_list: todo_list, completed: false) }
    let!(:item3) { create(:item, todo_list: todo_list, completed: false) }
    let!(:other_todo_list) { create(:todo_list) }
    let!(:other_item) { create(:item, todo_list: other_todo_list, completed: false) }

    context "when given all: true" do
      it "returns 202 with task_id and enqueues job to update all items" do
        expect {
          patch "#{base_path}/bulk_update", params: { all: true }, as: :json
        }.to have_enqueued_job(ItemsBulkUpdateJob).with(
          todo_list.id,
          anything,
          item_ids: [],
          all: true
        )

        expect(response).to have_http_status :accepted
        parsed = response.parsed_body
        expect(parsed).to have_key 'task_id'
        expect(parsed['task_id']).to match(/\A[0-9a-f-]{36}\z/)

        perform_enqueued_jobs
        expect(item1.reload.completed).to be true
        expect(item2.reload.completed).to be true
        expect(item3.reload.completed).to be true
        expect(other_item.reload.completed).to be false
      end
    end

    context "when given specific item_ids" do
      it "returns 202 with task_id and enqueues job to update specified items" do
        expect {
          patch "#{base_path}/bulk_update", params: { item_ids: [ item1.id, item3.id ] }, as: :json
        }.to have_enqueued_job(ItemsBulkUpdateJob).with(
          todo_list.id,
          anything,
          item_ids: [ item1.id, item3.id ],
          all: false
        )

        expect(response).to have_http_status :accepted
        parsed = response.parsed_body
        expect(parsed).to have_key 'task_id'
        expect(parsed['task_id']).to match(/\A[0-9a-f-]{36}\z/)

        perform_enqueued_jobs
        expect(item1.reload.completed).to be true
        expect(item3.reload.completed).to be true
        expect(item2.reload.completed).to be false
      end
    end

    context "when given no valid parameters" do
      it "returns 202 with task_id and enqueues job that updates no items" do
        expect {
          patch "#{base_path}/bulk_update", params: {}, as: :json
        }.to have_enqueued_job(ItemsBulkUpdateJob).with(
          todo_list.id,
          anything,
          item_ids: [],
          all: false
        )

        expect(response).to have_http_status :accepted
        parsed = response.parsed_body
        expect(parsed).to have_key 'task_id'

        perform_enqueued_jobs
        expect(item1.reload.completed).to be false
        expect(item2.reload.completed).to be false
      end
    end
  end
end
