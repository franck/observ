import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    console.log('[Observ] autoscroll controller connected')
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
    })
    
    this.observer.observe(this.containerTarget, {
      childList: true,
      subtree: true
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      const lastMessage = this.containerTarget.lastElementChild
      if (lastMessage) {
        lastMessage.scrollIntoView({ behavior: "smooth", block: "start" })
      }
    })
  }
}
