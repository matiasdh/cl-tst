class TodoListChannel < ApplicationCable::Channel
  def subscribed
    stream_from "todo_list_#{params[:todo_list_id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
