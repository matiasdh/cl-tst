module Api
  class TodoListsController < ApiController
    def index
      @todo_lists = TodoList.with_associations.order(id: :desc)
    end

    def create
      @todo_list = Todos::CreateTodoListService.call(name: todo_list_params[:name])
      render :show, status: :created
    end

    def update
      @todo_list = Todos::UpdateTodoListService.call(todo_list:, **todo_list_params)
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
      params.permit(:name)
    end
  end
end
