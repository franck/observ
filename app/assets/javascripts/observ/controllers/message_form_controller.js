import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "loadingIndicator"]
  static values = { loading: { type: Boolean, default: false } }

  connect() {
    console.log('[Observ] message-form controller connected')
    this.toggleSubmit()
    this.boundHandleTurboSubmit = this.handleTurboSubmit.bind(this)
    this.boundHandleTurboRender = this.handleTurboRender.bind(this)
    
    this.element.addEventListener('turbo:submit-start', this.boundHandleTurboSubmit)
    document.addEventListener('turbo:before-stream-render', this.boundHandleTurboRender)
  }

  disconnect() {
    this.element.removeEventListener('turbo:submit-start', this.boundHandleTurboSubmit)
    document.removeEventListener('turbo:before-stream-render', this.boundHandleTurboRender)
  }

  loadingValueChanged() {
    this.updateUI()
  }

  toggleSubmit() {
    this.updateUI()
  }

  updateUI() {
    const hasContent = this.inputTarget.value.trim().length > 0
    const canSubmit = hasContent && !this.loadingValue
    
    this.submitTarget.disabled = !canSubmit
    
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.style.display = this.loadingValue ? 'inline-flex' : 'none'
    }
    
    this.submitTarget.style.display = this.loadingValue ? 'none' : 'inline-flex'
  }

  handleTurboSubmit(event) {
    if (this.inputTarget.value.trim().length > 0) {
      this.loadingValue = true
    }
  }

  handleTurboRender(event) {
    const streamElement = event.target
    if (streamElement.target === 'new_message' || streamElement.target === 'messages') {
      setTimeout(() => {
        this.loadingValue = false
        this.toggleSubmit()
      }, 100)
    }
  }
}
