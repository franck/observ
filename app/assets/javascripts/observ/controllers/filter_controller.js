import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  connect() {
    console.log('[Observ] filter controller connected')
  }

  submit(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  clear(event) {
    event.preventDefault()
    
    this.inputTargets.forEach(input => {
      if (input.type === "text" || input.type === "date") {
        input.value = ""
      } else if (input.type === "select-one") {
        input.selectedIndex = 0
      }
    })

    this.formTarget.requestSubmit()
  }

  autoSubmit() {
    clearTimeout(this.timeout)
    
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 500)
  }
}
