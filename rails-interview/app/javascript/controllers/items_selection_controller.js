import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "completeSelectedButton", "checkbox", "form"]

  connect() {
    this.updateState()
  }

  toggleAll(event) {
    const checked = event.target.checked

    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checked
    })

    this.updateState()
  }

  checkboxChanged() {
    this.updateState()
  }

  resetSelection() {
    this.updateState()
  }

  syncSelection() {
    if (!this.hasFormTarget) return

    this.formTarget
      .querySelectorAll('input[data-items-selection-generated="true"]')
      .forEach((input) => input.remove())

    this.checkboxTargets
      .filter((checkbox) => checkbox.checked)
      .forEach((checkbox) => {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "item_ids[]"
        hidden.value = checkbox.value
        hidden.dataset.itemsSelectionGenerated = "true"
        this.formTarget.appendChild(hidden)
      })
  }

  updateState() {
    const total = this.checkboxTargets.length
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked).length

    if (this.hasCompleteSelectedButtonTarget) {
      this.completeSelectedButtonTarget.disabled = selected === 0
    }

    if (this.hasSelectAllTarget) {
      const selectAll = this.selectAllTarget

      if (total === 0 || selected === 0) {
        selectAll.checked = false
        selectAll.indeterminate = false
      } else if (selected === total) {
        selectAll.checked = true
        selectAll.indeterminate = false
      } else {
        selectAll.checked = false
        selectAll.indeterminate = true
      }
    }

    this.syncSelection()
  }
}

