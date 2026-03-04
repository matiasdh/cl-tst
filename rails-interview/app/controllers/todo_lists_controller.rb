class TodoListsController < ApplicationController
  helper_method :todo_list

  # GET /todolists
  def index
    @todo_lists = TodoList.with_associations.order(id: :desc)
  end

  # GET /todolists/:id
  def show
  end

  # GET /todolists/new
  def new
    @todo_list = TodoList.new
  end

  # POST /todolists
  def create
    @todo_list = Todos::CreateTodoListService.call(name: todo_list_params[:name])

    redirect_to @todo_list, notice: "Todo list created successfully."
  end

  # GET /todolists/:id/edit
  def edit
  end

  # PATCH/PUT /todolists/:id
  def update
    Todos::UpdateTodoListService.call(todo_list:, **todo_list_params.to_h.symbolize_keys)

    redirect_to todo_list, notice: "Todo list updated successfully."
  end

  # DELETE /todolists/:id
  def destroy
    Todos::DestroyTodoListService.call(todo_list:)

    redirect_to todo_lists_path, notice: "Todo list deleted successfully."
  end

  private

  def todo_list
    @todo_list ||= TodoList.with_associations.find(params[:id])
  end

  def todo_list_params
    params.require(:todo_list).permit(:name)
  end
end
