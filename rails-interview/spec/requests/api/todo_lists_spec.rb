require "rails_helper"

RSpec.describe "Api::TodoLists", type: :request do
  let(:base_path) { "/api/todolists" }

  describe "GET /api/todolists" do
    it "returns 406 when format is not JSON" do
      get "#{base_path}.html"

      expect(response).to have_http_status(:not_acceptable)
    end

    it "returns 200 and JSON array of todo lists" do
      todo_list = create(:todo_list, name: "My List")

      get base_path, as: :json

      expect(response).to have_http_status(:ok)
      parsed = response.parsed_body
      expect(parsed).to be_an(Array)
      expect(parsed.first).to include("id" => todo_list.id, "name" => "My List")
    end
  end

  describe "POST /api/todolists" do
    it "creates a todo list and returns its representation" do
      expect {
        post base_path, params: { name: "Example List" }, as: :json
      }.to change(TodoList, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("id", "name" => "Example List", "items" => [])
    end

    context "when validation fails" do
      it "returns 422 when name is blank" do
        post base_path, params: { name: "" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        parsed = response.parsed_body
        expect(parsed).to have_key("errors")
        expect(parsed["errors"]).not_to be_empty
      end

      it "returns 422 when name is missing" do
        post base_path, params: {}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PUT /api/todolists/:id" do
    let(:todo_list) { create(:todo_list, name: "Original Name") }

    it "updates the todo list and returns its representation" do
      put "#{base_path}/#{todo_list.id}", params: { name: "Updated List Name" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => todo_list.id, "name" => "Updated List Name")
      expect(todo_list.reload.name).to eq("Updated List Name")
    end

    it "returns 422 when name is blank" do
      put "#{base_path}/#{todo_list.id}", params: { name: "" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to have_key("errors")
    end

    it "returns 404 when todo_list does not exist" do
      put "#{base_path}/invalid_id", params: { name: "Updated" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 200 and keeps record unchanged when body is empty" do
      put "#{base_path}/#{todo_list.id}", params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(todo_list.reload.name).to eq("Original Name")
    end
  end

  describe "DELETE /api/todolists/:id" do
    let!(:todo_list) { create(:todo_list) }

    it "deletes the todo list and returns 204" do
      expect {
        delete "#{base_path}/#{todo_list.id}", as: :json
      }.to change(TodoList, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 when todo_list does not exist" do
      delete "#{base_path}/invalid_id", as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "deletes associated items via cascade" do
      create_list(:item, 3, todo_list: todo_list)

      expect {
        delete "#{base_path}/#{todo_list.id}", as: :json
      }.to change(Item, :count).by(-3)
    end
  end
end
