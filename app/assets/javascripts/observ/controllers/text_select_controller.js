import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]

  select(event) {
    event.preventDefault()
    this.textTarget.select()
  }
}
