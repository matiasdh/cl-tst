require "rails_helper"

RSpec.describe ExternalTodoApi::TodoLists do
  let(:base_url) { "http://localhost:3001" }
  let(:client) { ExternalTodoApi::Client.new }
  let(:todo_lists) { described_class.new(client) }

  describe "#list" do
    let(:todo_lists_json) do
      [
        {
          id: 1,
          source_id: "src-1",
          name: "List 1",
          created_at: "2024-01-01T00:00:00Z",
          updated_at: "2024-01-01T00:00:00Z",
          items: [
            {
              id: 10,
              source_id: "item-1",
              description: "Item A",
              completed: false,
              created_at: "2024-01-01T00:00:00Z",
              updated_at: "2024-01-01T00:00:00Z"
            }
          ]
        }
      ]
    end

    before do
      stub_request(:get, "#{base_url}/todolists")
        .to_return(status: 200, body: todo_lists_json.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns parsed TodoList structs with nested TodoItems" do
      result = todo_lists.list

      expect(result).to be_an(Array)
      expect(result.size).to eq 1
      expect(result.first).to be_a(ExternalTodoApi::TodoList)
      expect(result.first.id).to eq 1
      expect(result.first.name).to eq "List 1"
      expect(result.first.items.size).to eq 1
      expect(result.first.items.first).to be_a(ExternalTodoApi::TodoItem)
      expect(result.first.items.first.description).to eq "Item A"
    end

  end

  describe "#create" do
    let(:payload) do
      ExternalTodoApi::CreateTodoList.new(
        source_id: "src-1",
        name: "New List",
        items: [
          ExternalTodoApi::CreateTodoItem.new(description: "First item", completed: false)
        ]
      )
    end

    let(:response_body) do
      {
        id: 99,
        source_id: "src-1",
        name: "New List",
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z",
        items: []
      }
    end

    before do
      stub_request(:post, "#{base_url}/todolists")
        .with(
          body: { source_id: "src-1", name: "New List", items: [ { description: "First item", completed: false } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 201, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "sends CreateTodoList as JSON and returns parsed TodoList" do
      result = todo_lists.create(payload)

      expect(result).to be_a(ExternalTodoApi::TodoList)
      expect(result.id).to eq 99
      expect(result.name).to eq "New List"
    end
  end

  describe "#update" do
    before do
      stub_request(:patch, "#{base_url}/todolists/1")
        .with(body: { name: "Updated Name" }.to_json, headers: { "Content-Type" => "application/json" })
        .to_return(status: 200, body: { id: 1, name: "Updated Name" }.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "sends PATCH with name and returns parsed TodoList" do
      result = todo_lists.update(id: 1, name: "Updated Name")

      expect(result).to be_a(ExternalTodoApi::TodoList)
      expect(result.name).to eq "Updated Name"
    end
  end

  describe "#delete" do
    before do
      stub_request(:delete, "#{base_url}/todolists/1").to_return(status: 204)
    end

    it "sends DELETE and returns true" do
      result = todo_lists.delete(id: 1)

      expect(result).to be true
    end
  end

  describe "#items#update" do
    before do
      stub_request(:patch, "#{base_url}/todolists/1/todoitems/10")
        .with(body: { completed: true }.to_json, headers: { "Content-Type" => "application/json" })
        .to_return(
          status: 200,
          body: { id: 10, description: "Item", completed: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "sends only non-nil attributes in body and returns parsed TodoItem" do
      result = todo_lists.items.update(todo_list_id: 1, todo_item_id: 10, completed: true)

      expect(result).to be_a(ExternalTodoApi::TodoItem)
      expect(result.completed).to be true
    end
  end

  describe "#items#delete" do
    before do
      stub_request(:delete, "#{base_url}/todolists/1/todoitems/10").to_return(status: 204)
    end

    it "sends DELETE and returns true" do
      result = todo_lists.items.delete(todo_list_id: 1, todo_item_id: 10)

      expect(result).to be true
    end
  end

  describe "error handling" do
    context "when API returns 404" do
      before do
        stub_request(:get, "#{base_url}/todolists").to_return(status: 404, body: "Not found")
      end

      it "raises NotFoundError" do
        expect { todo_lists.list }.to raise_error(ExternalTodoApi::NotFoundError)
      end
    end

    context "when API returns 500" do
      before do
        stub_request(:get, "#{base_url}/todolists").to_return(status: 500, body: "Internal error")
      end

      it "raises ServerError" do
        expect { todo_lists.list }.to raise_error(ExternalTodoApi::ServerError)
      end
    end
  end
end
