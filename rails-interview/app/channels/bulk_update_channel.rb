class BulkUpdateChannel < ApplicationCable::Channel
  def subscribed
    stream_from "bulk_update_#{params[:task_id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
