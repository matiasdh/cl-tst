import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = {
    todoListId: String,
    frameId: String
  }

  connect() {
    this.subscription = createConsumer().subscriptions.create(
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
    if (frame) {
      const url = window.location.pathname + window.location.search
      frame.src = url
    }
  }
}
