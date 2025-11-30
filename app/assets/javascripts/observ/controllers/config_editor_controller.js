import { Controller } from "@hotwired/stimulus"

/**
 * Config Editor Controller
 * 
 * Handles bi-directional sync between structured form fields and JSON textarea.
 * Provides real-time JSON validation with visual feedback.
 * 
 * Targets:
 *   - model: Select dropdown for model selection
 *   - temperature: Number input for temperature
 *   - maxTokens: Number input for max_tokens
 *   - jsonInput: Textarea for advanced JSON editing
 *   - status: Element to display validation status
 *   - hiddenField: Hidden input that submits the final JSON
 * 
 * Values:
 *   - knownKeys: Array of keys managed by structured fields (default: ["model", "temperature", "max_tokens"])
 */
export default class extends Controller {
  static targets = ["model", "temperature", "maxTokens", "jsonInput", "status", "hiddenField"]
  static values = {
    knownKeys: { type: Array, default: ["model", "temperature", "max_tokens"] }
  }

  connect() {
    console.log('[Observ] config-editor controller connected')
    this.syncFromHiddenField()
  }

  // Called when any structured field changes
  syncToJson() {
    const config = this.buildConfigFromFields()
    const jsonString = Object.keys(config).length > 0 
      ? JSON.stringify(config, null, 2) 
      : ""
    
    if (this.hasJsonInputTarget) {
      this.jsonInputTarget.value = jsonString
    }
    this.updateHiddenField(config)
    this.showValidStatus()
  }

  // Called when JSON textarea changes
  syncFromJson() {
    const jsonString = this.jsonInputTarget.value.trim()
    
    if (jsonString === "") {
      this.clearStructuredFields()
      this.updateHiddenField({})
      this.showValidStatus()
      return
    }

    try {
      const config = JSON.parse(jsonString)
      this.populateStructuredFields(config)
      this.updateHiddenField(config)
      this.showValidStatus()
    } catch (e) {
      this.showInvalidStatus(e.message)
    }
  }

  // Build config object from structured fields
  buildConfigFromFields() {
    const config = this.getExtraJsonKeys()

    if (this.hasModelTarget && this.modelTarget.value) {
      config.model = this.modelTarget.value
    }
    if (this.hasTemperatureTarget && this.temperatureTarget.value !== "") {
      config.temperature = parseFloat(this.temperatureTarget.value)
    }
    if (this.hasMaxTokensTarget && this.maxTokensTarget.value !== "") {
      config.max_tokens = parseInt(this.maxTokensTarget.value, 10)
    }

    return config
  }

  // Get any extra keys from JSON that aren't in structured fields
  getExtraJsonKeys() {
    if (!this.hasJsonInputTarget || this.jsonInputTarget.value.trim() === "") {
      return {}
    }

    try {
      const fullConfig = JSON.parse(this.jsonInputTarget.value)
      const extra = {}
      
      Object.keys(fullConfig).forEach(key => {
        if (!this.knownKeysValue.includes(key)) {
          extra[key] = fullConfig[key]
        }
      })
      
      return extra
    } catch {
      return {}
    }
  }

  // Populate structured fields from config object
  populateStructuredFields(config) {
    if (this.hasModelTarget && config.model !== undefined) {
      this.modelTarget.value = config.model
    }
    if (this.hasTemperatureTarget && config.temperature !== undefined) {
      this.temperatureTarget.value = config.temperature
    }
    if (this.hasMaxTokensTarget && config.max_tokens !== undefined) {
      this.maxTokensTarget.value = config.max_tokens
    }
  }

  // Clear all structured fields
  clearStructuredFields() {
    if (this.hasModelTarget) this.modelTarget.value = ""
    if (this.hasTemperatureTarget) this.temperatureTarget.value = ""
    if (this.hasMaxTokensTarget) this.maxTokensTarget.value = ""
  }

  // Load initial state from hidden field
  syncFromHiddenField() {
    if (!this.hasHiddenFieldTarget) return

    const jsonString = this.hiddenFieldTarget.value.trim()
    if (jsonString === "") return

    try {
      const config = JSON.parse(jsonString)
      this.populateStructuredFields(config)
      
      if (this.hasJsonInputTarget) {
        this.jsonInputTarget.value = JSON.stringify(config, null, 2)
      }
      this.showValidStatus()
    } catch {
      // If initial value is invalid, just show it in the textarea
      if (this.hasJsonInputTarget) {
        this.jsonInputTarget.value = jsonString
      }
      this.showInvalidStatus("Initial config is invalid JSON")
    }
  }

  // Update the hidden field that gets submitted
  updateHiddenField(config) {
    if (!this.hasHiddenFieldTarget) return
    this.hiddenFieldTarget.value = Object.keys(config).length > 0 
      ? JSON.stringify(config) 
      : ""
  }

  // Show valid status
  showValidStatus() {
    if (!this.hasStatusTarget) return
    this.statusTarget.innerHTML = '<span class="observ-config-editor__status--valid">&#10003; Valid JSON</span>'
    this.statusTarget.classList.remove("observ-config-editor__status--error")
    this.statusTarget.classList.add("observ-config-editor__status--success")
  }

  // Show invalid status with error message
  showInvalidStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.innerHTML = `<span class="observ-config-editor__status--invalid">&#10007; Invalid JSON: ${this.escapeHtml(message)}</span>`
    this.statusTarget.classList.remove("observ-config-editor__status--success")
    this.statusTarget.classList.add("observ-config-editor__status--error")
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
