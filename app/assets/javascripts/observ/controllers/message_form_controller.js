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
    
    // Show/hide typing indicator in messages area
    const typingIndicator = document.getElementById('typing-indicator')
    if (typingIndicator) {
      typingIndicator.style.display = this.loadingValue ? 'flex' : 'none'
    }
  }

  handleTurboSubmit(event) {
    if (this.inputTarget.value.trim().length > 0) {
      this.loadingValue = true
    }
  }

  handleTurboRender(event) {
    const streamElement = event.target
    
    // Only reset loading when the form is replaced (after user message submitted)
    // The typing indicator will be hidden when assistant message arrives
    if (streamElement.target === 'new_message') {
      // Form was replaced, re-enable submit but keep typing indicator showing
      setTimeout(() => {
        this.toggleSubmit()
      }, 100)
    }
    
    // Hide typing indicator when an assistant message is appended
    if (streamElement.target === 'messages') {
      const action = streamElement.getAttribute('action')
      // Check if this is an append (new message) containing assistant content
      if (action === 'append') {
        const content = streamElement.innerHTML
        // Check if it's an assistant message (has the assistant class)
        if (content.includes('observ-chat-message--assistant')) {
          this.loadingValue = false
        }
      }
    }
  }
}
