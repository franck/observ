import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="observ--chat-form"
export default class extends Controller {
  static targets = ["agentSelect", "promptVersionGroup", "promptVersionSelect"]
  static values = { 
    promptsUrl: String,
    agentsWithPrompts: Object  // Map of agent_name => prompt_name
  }
  
  connect() {
    console.log('[Observ] chat-form controller connected')
    console.log('  - Prompts URL:', this.promptsUrlValue)
    console.log('  - Agents with prompts:', this.agentsWithPromptsValue)
    this.togglePromptVersionField()
  }
  
  disconnect() {
    console.log('[Observ] chat-form controller disconnected')
  }
  
  agentChanged() {
    console.log('[Observ] Agent selection changed')
    this.togglePromptVersionField()
  }
  
  togglePromptVersionField() {
    if (!this.hasAgentSelectTarget) {
      console.warn('[Observ] Agent select target not found')
      return
    }
    
    const selectedAgent = this.agentSelectTarget.value
    console.log('  - Selected agent:', selectedAgent)
    
    const promptName = this.agentsWithPromptsValue[selectedAgent]
    console.log('  - Prompt name for agent:', promptName)
    
    if (promptName) {
      this.loadPromptVersions(promptName)
      this.showPromptVersionField()
    } else {
      this.hidePromptVersionField()
    }
  }
  
  loadPromptVersions(promptName) {
    const url = `${this.promptsUrlValue}/${promptName}/versions.json`
    console.log('  - Fetching versions from:', url)
    
    fetch(url)
      .then(response => {
        console.log('  - Response status:', response.status)
        if (!response.ok) {
          throw new Error(`Failed to fetch prompt versions: ${response.status}`)
        }
        return response.json()
      })
      .then(data => {
        console.log('  - Versions loaded:', data.length, 'version(s)')
        this.populateVersions(data)
      })
      .catch(error => {
        console.error('[Observ] Error loading prompt versions:', error)
        // On error, hide the field gracefully
        this.hidePromptVersionField()
      })
  }
  
  populateVersions(versions) {
    this.promptVersionSelectTarget.innerHTML = this.buildVersionOptions(versions)
  }
  
  buildVersionOptions(versions) {
    const defaultOption = '<option value="">Use default (production)</option>'
    const versionOptions = versions.map(v => {
      const commitMsg = v.commit_message ? ` - ${v.commit_message}` : ''
      return `<option value="${v.version}">v${v.version} - ${v.state}${commitMsg}</option>`
    }).join('')
    
    return defaultOption + versionOptions
  }
  
  showPromptVersionField() {
    this.promptVersionGroupTarget.classList.remove('observ-hidden')
  }
  
  hidePromptVersionField() {
    this.promptVersionGroupTarget.classList.add('observ-hidden')
    // Clear the select value when hiding
    this.promptVersionSelectTarget.value = ''
  }
}
