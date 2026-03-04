require "rails_helper"

RSpec.describe "Todo lists web UI", type: :request do
  describe "GET /todolists" do
    it "renders the list of todo lists" do
      todo_list = create(:todo_list)

      get "/todolists"

      expect(response).to have_http_status :ok
      expect(response.body).to include todo_list.name
    end
  end

  describe "GET /todolists/:id" do
    it "renders the todo list detail with items section" do
      todo_list = create(:todo_list)

      get "/todolists/#{todo_list.id}"

      expect(response).to have_http_status :ok
      expect(response.body).to include todo_list.name
      expect(response.body).to include "Items"
    end
  end

  describe "PATCH /todolists/:todo_list_id/items/:id/complete" do
    it "marks a single item as completed" do
      todo_list = create(:todo_list)
      item = create(:item, todo_list:)

      patch "/todolists/#{todo_list.id}/items/#{item.id}/complete"

      expect(response).to redirect_to todo_list
      expect(item.reload.completed).to be true
    end
  end

  describe "PATCH /todolists/:todo_list_id/items/complete_selected" do
    it "marks selected items as completed" do
      todo_list = create(:todo_list)
      item_1 = create(:item, todo_list:)
      item_2 = create(:item, todo_list:)
      create(:item, todo_list:)

      patch "/todolists/#{todo_list.id}/items/complete_selected",
            params: { item_ids: [ item_1.id, item_2.id ] }

      expect(response).to redirect_to todo_list
      expect(item_1.reload.completed).to be true
      expect(item_2.reload.completed).to be true
    end
  end

  describe "PATCH /todolists/:todo_list_id/items/complete_all" do
    it "marks all items in the list as completed" do
      todo_list = create(:todo_list)
      item_1 = create(:item, todo_list:)
      item_2 = create(:item, todo_list:)

      patch "/todolists/#{todo_list.id}/items/complete_all"

      expect(response).to redirect_to todo_list
      expect(item_1.reload.completed).to be true
      expect(item_2.reload.completed).to be true
    end
  end
end

