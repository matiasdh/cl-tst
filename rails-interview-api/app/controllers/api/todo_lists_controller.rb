module Api
  class TodoListsController < ApiController
    def index
      @todo_lists = TodoList.with_associations.order(id: :desc)
    end

    def create
      @todo_list = Todos::CreateTodoListService.call(
        name: todo_list_params[:name],
        source_id: todo_list_params[:source_id],
        items: todo_list_params[:items] || []
      )
      render :show, status: :created
    end

    def update
      update_attrs = params.permit(:name).to_h.compact
      @todo_list = Todos::UpdateTodoListService.call(todo_list:, **update_attrs)
      render :show
    end

    def destroy
      Todos::DestroyTodoListService.call(todo_list:)
      head :no_content
    end

    private

    def todo_list
      @todo_list ||= TodoList.find(params[:id])
    end

    def todo_list_params
      params.permit(:name, :source_id, items: [:source_id, :description, :completed])
    end
  end
end
