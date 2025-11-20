import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static classes = ["success"]
  static values = {
    successDuration: { type: Number, default: 2000 }
  }

  connect() {
    console.log('[Observ] copy controller connected')
  }

  copy(event) {
    event.preventDefault()

    const text = this.sourceTarget.textContent || this.sourceTarget.value

    navigator.clipboard.writeText(text).then(() => {
      this.showSuccess()
    }).catch(err => {
      console.error('Failed to copy text: ', err)
    })
  }

  showSuccess() {
    const originalText = this.buttonTarget.textContent

    this.buttonTarget.textContent = "Copied!"
    
    if (this.hasSuccessClass) {
      this.buttonTarget.classList.add(...this.successClasses)
    }

    setTimeout(() => {
      this.buttonTarget.textContent = originalText
      
      if (this.hasSuccessClass) {
        this.buttonTarget.classList.remove(...this.successClasses)
      }
    }, this.successDurationValue)
  }
}
