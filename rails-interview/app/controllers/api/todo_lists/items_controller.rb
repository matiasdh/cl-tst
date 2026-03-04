module Api
  module TodoLists
    class ItemsController < ApiController
      def index
        @items = todo_list.items
      end

      def create
        @item = Todos::CreateItemService.call(
          todo_list:,
          description: item_params[:description],
          completed: item_params[:completed]
        )
        render :show, status: :created
      end

      def update
        @item = Todos::UpdateItemService.call(
          item: todo_list.items.find(params[:id]),
          description: item_params[:description],
          completed: item_params[:completed]
        )
        render :show
      end

      def destroy
        @item = todo_list.items.find(params[:id])
        Todos::DestroyItemService.call(item: @item)
        head :no_content
      end

      def bulk_update
        task_id = Todos::BulkUpdateItemsService.call(
          todo_list:,
          item_ids: bulk_update_params[:item_ids] || [],
          all: [ true, "true", "1" ].include?(bulk_update_params[:all])
        )

        render json: { task_id: }, status: :accepted
      end

      private

      def bulk_update_params
        params.permit(:all, item_ids: [])
      end

      def todo_list
        @todo_list ||= TodoList.with_associations.find(params[:todo_list_id])
      end

      def item_params
        params.require(:item).permit(:description, :completed)
      end
    end
  end
end
