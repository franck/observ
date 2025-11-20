import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toggle"]
  static classes = ["expanded"]
  static values = {
    expanded: { type: Boolean, default: false }
  }

  connect() {
    console.log('[Observ] expandable controller connected')
    this.updateState()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.updateState()
  }

  updateState() {
    if (this.expandedValue) {
      this.contentTarget.classList.remove("hidden")
      if (this.hasToggleTarget) {
        this.toggleTarget.textContent = "Collapse ▲"
      }
    } else {
      this.contentTarget.classList.add("hidden")
      if (this.hasToggleTarget) {
        this.toggleTarget.textContent = "Expand ▼"
      }
    }
  }
}
