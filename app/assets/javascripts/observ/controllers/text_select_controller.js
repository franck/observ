import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]

  connect() {
    console.log('[Observ] text-select controller connected')
  }

  select(event) {
    event.preventDefault()
    this.textTarget.select()
  }
}
