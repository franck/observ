import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    data: String
  }

  connect() {
    // Parse the JSON string to get the actual data
    let data
    try {
      data = JSON.parse(this.dataValue)
    } catch (error) {
      console.error('Failed to parse JSON data:', error)
      this.element.innerHTML = '<p style="color: red;">Error parsing JSON data</p>'
      return
    }
    
    // Clear any existing content
    this.element.innerHTML = ''
    
    // Render the JSON
    const container = document.createElement('div')
    container.className = 'json-container'
    container.appendChild(this.render(data, 0))
    this.element.appendChild(container)
  }

  render(data, level) {
    if (data === null) return this.renderNull()
    if (Array.isArray(data)) return this.renderArray(data, level)
    if (typeof data === 'object') return this.renderObject(data, level)
    if (typeof data === 'string') return this.renderString(data)
    if (typeof data === 'number') return this.renderNumber(data)
    if (typeof data === 'boolean') return this.renderBoolean(data)
    
    // Fallback
    return this.renderUnknown(data)
  }

  renderObject(obj, level) {
    const keys = Object.keys(obj)
    
    if (keys.length === 0) {
      return this.createSpan('json-punctuation', '{}')
    }

    const container = document.createElement('div')
    container.className = 'json-object'
    
    // Opening brace
    const header = document.createElement('div')
    header.className = 'json-line'
    
    const toggle = this.createToggle(true)
    const openBrace = this.createSpan('json-punctuation', '{')
    const itemCount = this.createSpan('json-item-count', ` ${keys.length} ${keys.length === 1 ? 'item' : 'items'}`)
    itemCount.style.display = 'none'
    
    header.appendChild(toggle)
    header.appendChild(openBrace)
    header.appendChild(itemCount)
    container.appendChild(header)
    
    // Content
    const content = document.createElement('div')
    content.className = 'json-content'
    
    keys.forEach((key, index) => {
      const line = document.createElement('div')
      line.className = 'json-line'
      
      const indent = this.createIndent(level + 1)
      const keySpan = this.createSpan('json-key', `"${key}"`)
      const colon = this.createSpan('json-punctuation', ': ')
      
      line.appendChild(indent)
      line.appendChild(keySpan)
      line.appendChild(colon)
      
      const valueElement = this.render(obj[key], level + 1)
      if (valueElement.classList && (valueElement.classList.contains('json-object') || valueElement.classList.contains('json-array'))) {
        line.appendChild(valueElement)
      } else {
        line.appendChild(valueElement)
      }
      
      if (index < keys.length - 1) {
        line.appendChild(this.createSpan('json-punctuation', ','))
      }
      
      content.appendChild(line)
    })
    
    container.appendChild(content)
    
    // Closing brace
    const footer = document.createElement('div')
    footer.className = 'json-line json-footer'
    footer.appendChild(this.createIndent(level))
    footer.appendChild(this.createSpan('json-punctuation', '}'))
    container.appendChild(footer)
    
    // Add toggle functionality
    toggle.addEventListener('click', (e) => {
      e.preventDefault()
      this.toggleCollapse(toggle, content, itemCount, footer)
    })
    
    return container
  }

  renderArray(arr, level) {
    if (arr.length === 0) {
      return this.createSpan('json-punctuation', '[]')
    }

    const container = document.createElement('div')
    container.className = 'json-array'
    
    // Opening bracket
    const header = document.createElement('div')
    header.className = 'json-line'
    
    const toggle = this.createToggle(true)
    const openBracket = this.createSpan('json-punctuation', '[')
    const itemCount = this.createSpan('json-item-count', ` ${arr.length} ${arr.length === 1 ? 'item' : 'items'}`)
    itemCount.style.display = 'none'
    
    header.appendChild(toggle)
    header.appendChild(openBracket)
    header.appendChild(itemCount)
    container.appendChild(header)
    
    // Content
    const content = document.createElement('div')
    content.className = 'json-content'
    
    arr.forEach((item, index) => {
      const line = document.createElement('div')
      line.className = 'json-line'
      
      const indent = this.createIndent(level + 1)
      line.appendChild(indent)
      
      const valueElement = this.render(item, level + 1)
      line.appendChild(valueElement)
      
      if (index < arr.length - 1) {
        line.appendChild(this.createSpan('json-punctuation', ','))
      }
      
      content.appendChild(line)
    })
    
    container.appendChild(content)
    
    // Closing bracket
    const footer = document.createElement('div')
    footer.className = 'json-line json-footer'
    footer.appendChild(this.createIndent(level))
    footer.appendChild(this.createSpan('json-punctuation', ']'))
    container.appendChild(footer)
    
    // Add toggle functionality
    toggle.addEventListener('click', (e) => {
      e.preventDefault()
      this.toggleCollapse(toggle, content, itemCount, footer)
    })
    
    return container
  }

  renderString(str) {
    // Unescape special characters
    const unescaped = str.replace(/\\n/g, '\n')
                         .replace(/\\t/g, '  ')
                         .replace(/\\r/g, '')
    
    const span = document.createElement('span')
    span.className = 'json-string'
    
    // Add opening quote
    const openQuote = this.createSpan('json-quote', '"')
    span.appendChild(openQuote)
    
    // Add the actual string content
    const content = document.createElement('span')
    content.className = 'json-string-content'
    content.textContent = unescaped
    span.appendChild(content)
    
    // Add closing quote
    const closeQuote = this.createSpan('json-quote', '"')
    span.appendChild(closeQuote)
    
    return span
  }

  renderNumber(num) {
    return this.createSpan('json-number', num.toString())
  }

  renderBoolean(bool) {
    return this.createSpan('json-boolean', bool.toString())
  }

  renderNull() {
    return this.createSpan('json-null', 'null')
  }

  renderUnknown(data) {
    return this.createSpan('json-unknown', String(data))
  }

  createSpan(className, text) {
    const span = document.createElement('span')
    span.className = className
    span.textContent = text
    return span
  }

  createIndent(level) {
    const span = document.createElement('span')
    span.className = 'json-indent'
    span.textContent = '  '.repeat(level) // 2 spaces per level
    return span
  }

  createToggle(expanded) {
    const toggle = document.createElement('span')
    toggle.className = 'json-toggle'
    toggle.textContent = expanded ? '▾' : '▸'
    toggle.style.cursor = 'pointer'
    toggle.style.userSelect = 'none'
    toggle.dataset.expanded = expanded
    return toggle
  }

  toggleCollapse(toggle, content, itemCount, footer) {
    const isExpanded = toggle.dataset.expanded === 'true'
    
    if (isExpanded) {
      // Collapse
      toggle.textContent = '▸'
      toggle.dataset.expanded = 'false'
      content.style.display = 'none'
      footer.style.display = 'none'
      itemCount.style.display = 'inline'
    } else {
      // Expand
      toggle.textContent = '▾'
      toggle.dataset.expanded = 'true'
      content.style.display = 'block'
      footer.style.display = 'block'
      itemCount.style.display = 'none'
    }
  }
}
