require "rails_helper"

RSpec.describe "Api::TodoLists::Items", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:todo_list) { create(:todo_list) }
  let(:base_path) { "/todolists/#{todo_list.id}/todoitems" }

  describe "PATCH update" do
    let(:item) { create(:item, todo_list: todo_list, description: "Original", completed: false) }

    it "updates description and completed" do
      patch "#{base_path}/#{item.id}", params: { description: "Updated", completed: true }, as: :json

      expect(response).to have_http_status(:ok)
      parsed = response.parsed_body
      expect(parsed).to include("id" => item.id.to_s, "description" => "Updated", "completed" => true)
      expect(parsed).to include("created_at", "updated_at")
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
        patch "/todolists/#{todo_list.id}/todoitems/#{other_item.id}", params: { description: "Updated" }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when item has no external_id (local only)" do
      let(:local_item) { create(:item, todo_list: todo_list, description: "Local", completed: false) }

      it "updates successfully" do
        patch "#{base_path}/#{local_item.id}", params: { completed: true }, as: :json

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
        delete "/todolists/#{todo_list.id}/todoitems/#{other_item.id}", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
