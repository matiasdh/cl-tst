import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = {
    todoListId: String,
    frameId: String
  }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "TodoListChannel", todo_list_id: this.todoListIdValue },
      {
        received: (data) => {
          if (data.action === "refresh_items") {
            this.refreshItemsFrame()
          }
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  refreshItemsFrame() {
    const frame = document.getElementById(this.frameIdValue)
    if (!frame) return

    const page = frame.dataset.currentPage || "1"
    const searchParams = new URLSearchParams(window.location.search)
    searchParams.set("page", page)
    const url = window.location.pathname + "?" + searchParams.toString()
    frame.src = url
  }
}
