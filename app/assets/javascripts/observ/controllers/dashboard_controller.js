import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["metrics"]
  static values = {
    refreshInterval: { type: Number, default: 30000 },
    autoRefresh: { type: Boolean, default: false }
  }

  connect() {
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    this.refreshTimer = setInterval(() => {
      this.refresh()
    }, this.refreshIntervalValue)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  async refresh() {
    try {
      const response = await fetch('/observ/dashboard/metrics', {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) {
        throw new Error('Network response was not ok')
      }

      const data = await response.json()
      this.updateMetrics(data)
    } catch (error) {
      console.error('Failed to refresh metrics:', error)
    }
  }

  updateMetrics(data) {
    if (this.hasMetricsTarget) {
      console.log('Metrics updated:', data)
    }
  }
}
