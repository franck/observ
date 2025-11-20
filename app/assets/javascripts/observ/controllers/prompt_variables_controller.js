import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for detecting and displaying {{variable}} patterns in prompt content.
 * 
 * Targets:
 *   - input: The textarea containing the prompt content
 *   - preview: The container element for the variables preview
 *   - list: The element that will contain the list of detected variables
 * 
 * Actions:
 *   - detectVariables: Triggered on input to scan for {{variable}} patterns
 * 
 * Usage:
 *   <div data-controller="observ--prompt-variables">
 *     <textarea data-observ--prompt-variables-target="input" 
 *               data-action="input->observ--prompt-variables#detectVariables"></textarea>
 *     <div data-observ--prompt-variables-target="preview">
 *       <div data-observ--prompt-variables-target="list"></div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "preview", "list"]

  connect() {
    console.log('[Observ] prompt-variables controller connected')
    // Detect variables on initial load
    this.detectVariables()
  }

  detectVariables() {
    const text = this.inputTarget.value
    const matches = text.match(/\{\{([^}]+)\}\}/g)

    if (matches && matches.length > 0) {
      const uniqueVars = [...new Set(matches)]
      this.displayVariables(uniqueVars)
      this.showPreview()
    } else {
      this.hidePreview()
    }
  }

  displayVariables(variables) {
    this.listTarget.innerHTML = variables.map(v =>
      `<span class="observ-badge observ-badge--info" style="font-size: 0.75rem;">${this.escapeHtml(v)}</span>`
    ).join('')
  }

  showPreview() {
    this.previewTarget.style.display = 'block'
  }

  hidePreview() {
    this.previewTarget.style.display = 'none'
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
