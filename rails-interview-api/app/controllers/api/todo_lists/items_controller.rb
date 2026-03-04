module Api
  module TodoLists
    class ItemsController < ApiController
      def update
        @item = Todos::UpdateItemService.call(
          item: todo_list.items.find(params[:todoitem_id]),
          description: item_params[:description],
          completed: item_params[:completed]
        )
        render :show
      end

      def destroy
        @item = todo_list.items.find(params[:todoitem_id])
        Todos::DestroyItemService.call(item: @item)
        head :no_content
      end

      private

      def todo_list
        @todo_list ||= TodoList.with_associations.find(params[:todo_list_id])
      end

      def item_params
        params.permit(:description, :completed)
      end
    end
  end
end
