import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "content", "headerTitle"]

  connect() {
    console.log('[Observ] drawer controller connected')
  }

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.drawerUrlParam

    if (!url) {
      console.error("No URL provided for drawer")
      return
    }

    this.drawerTarget.classList.add("open")
    this.replaceSpinners()
    this.fetchContent(url)
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    this.drawerTarget.classList.remove("open")
  }

  replaceSpinners() {
    this.headerTitleTarget.innerHTML = '<span class="observ-spinner"></span>'
    this.contentTarget.innerHTML = '<div class="observ-drawer__loading"><span class="observ-spinner"></span></div>'
  }

  async fetchContent(url) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "text/vnd.turbo-stream.html"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const html = await response.text()
      const turboStream = document.createElement("div")
      turboStream.innerHTML = html
      document.body.appendChild(turboStream)
      setTimeout(() => turboStream.remove(), 100)
    } catch (error) {
      console.error("Failed to fetch drawer content:", error)
      this.contentTarget.innerHTML = '<div class="observ-drawer__error">Failed to load content</div>'
    }
  }
}
