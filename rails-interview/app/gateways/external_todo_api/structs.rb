module ExternalTodoApi
  TodoItem = Struct.new(:id, :source_id, :description, :completed, :created_at, :updated_at, keyword_init: true) do
    def as_json
      to_h.compact
    end
  end.freeze

  TodoList = Struct.new(:id, :source_id, :name, :created_at, :updated_at, :items, keyword_init: true) do
    def items
      self[:items] || []
    end

    def as_json
      to_h.merge(items: items.map(&:as_json)).compact
    end
  end.freeze

  CreateTodoItem = Struct.new(:source_id, :description, :completed, keyword_init: true) do
    def self.from_record(item)
      new(
        source_id: item.external_source_id.presence || ExternalTodoApi.local_source_id,
        description: item.description,
        completed: item.completed
      )
    end

    def as_json
      to_h.compact
    end
  end.freeze

  CreateTodoList = Struct.new(:source_id, :name, :items, keyword_init: true) do
    def self.from_record(record)
      new(
        source_id: record.external_source_id.presence || ExternalTodoApi.local_source_id,
        name: record.name,
        items: record.items.order(:id).map { |i| CreateTodoItem.from_record(i) }
      )
    end

    def items
      self[:items] || []
    end

    def as_json
      { source_id:, name:, items: items.map(&:as_json) }.compact
    end
  end.freeze

  def self.local_source_id
    Rails.application.config.external_todo_api[:source_id].presence || "local"
  end
end
