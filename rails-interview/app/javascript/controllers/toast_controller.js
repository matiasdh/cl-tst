import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 5000 }
  }

  connect() {
    this.element.classList.add("translate-x-0")
    this.element.classList.remove("translate-x-full")

    this.timeoutId = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  dismiss() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }

    this.element.classList.add("translate-x-full")

    this.element.addEventListener(
      "transitionend",
      () => this.element.remove(),
      { once: true }
    )
  }
}
