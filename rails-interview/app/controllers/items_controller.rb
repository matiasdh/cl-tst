class ItemsController < ApplicationController
  include ActionView::RecordIdentifier
  helper_method :todo_list, :item

  # POST /todolists/:todo_list_id/items
  def create
    @item = Todos::CreateItemService.call(
      todo_list:,
      description: item_params[:description],
      completed: item_params[:completed]
    )
    flash.now[:notice] = "Item created successfully."
    set_items_frame_pagination

    respond_to do |format|
      format.html { redirect_to todo_list, notice: flash.now[:notice] }
      format.turbo_stream
    end
  end

  # PATCH/PUT /todolists/:todo_list_id/items/:id
  def update
    @item = Todos::UpdateItemService.call(
      item:,
      description: item_params[:description],
      completed: item_params[:completed]
    )
    flash.now[:notice] = "Item updated successfully."

    respond_to do |format|
      format.html { redirect_to todo_list, notice: flash.now[:notice] }
      format.turbo_stream
    end
  end

  # DELETE /todolists/:todo_list_id/items/:id
  def destroy
    Todos::DestroyItemService.call(item:)
    flash.now[:notice] = "Item deleted successfully."
    set_items_frame_pagination

    respond_to do |format|
      format.html { redirect_to todo_list, notice: flash.now[:notice] }
      format.turbo_stream
    end
  end

  # PATCH /todolists/:todo_list_id/items/:id/complete
  def complete
    @item = Todos::UpdateItemService.call(item:, completed: true)
    broadcast_item_completed(@item)
    flash.now[:notice] = "Item completed successfully."
    set_items_frame_pagination

    respond_to do |format|
      format.html { redirect_to todo_list, notice: flash.now[:notice] }
      format.turbo_stream
    end
  end

  # PATCH /todolists/:todo_list_id/items/complete_selected
  def complete_selected
    item_ids = bulk_update_params[:item_ids] || []
    perform_bulk_update(item_ids:, all: false)
  end

  # PATCH /todolists/:todo_list_id/items/complete_all
  def complete_all
    perform_bulk_update(item_ids: [], all: true)
  end

  private

  def todo_list
    @todo_list ||= TodoList.with_associations.find(params[:todo_list_id])
  end

  def item
    return unless params[:id]
    @item ||= todo_list.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:description, :completed)
  end

  def bulk_update_params
    params.permit(:page, item_ids: [])
  end

  def perform_bulk_update(item_ids:, all:)
    task_id = SecureRandom.uuid

    ItemsBulkUpdateJob.perform_now(
      todo_list.id,
      task_id,
      item_ids:,
      all:
    )

    todo_list.reload
    flash.now[:notice] = "Items completed successfully."
    set_items_frame_pagination

    respond_to do |format|
      format.html { redirect_to todo_list, notice: flash.now[:notice] }
      format.turbo_stream
    end
  end

  def set_items_frame_pagination
    @pagy, @items = pagy(:offset, todo_list.items.order(id: :desc), limit: 10, page: params[:page] || 1)
  end

  def broadcast_item_completed(item)
    Turbo::StreamsChannel.broadcast_replace_to(
      todo_list,
      target: dom_id(item),
      partial: "items/item",
      locals: { item: item }
    )
  end
end

