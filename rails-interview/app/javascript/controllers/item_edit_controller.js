import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['display', 'form']

  connect() {
    const initiallyVisible = this.formTarget.dataset.itemEditInitialVisible === 'true'

    if (initiallyVisible) {
      this.showForm()
    } else {
      this.showDisplay()
    }
  }

  showForm() {
    this.displayTarget.classList.add('hidden')
    this.displayTarget.style.display = 'none'

    this.formTarget.classList.remove('hidden')
    this.formTarget.style.display = ''
  }

  showDisplay() {
    this.formTarget.classList.add('hidden')
    this.formTarget.style.display = 'none'

    this.displayTarget.classList.remove('hidden')
    this.displayTarget.style.display = ''
  }
}
