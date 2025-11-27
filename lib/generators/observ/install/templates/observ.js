// Observ Vite entry point
// This file is loaded via vite_javascript_tag 'observ' in the Observ layout

// Import Turbo and Stimulus
import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'
import { registerControllers } from 'stimulus-vite-helpers'

// Import Observ stylesheets
import '../stylesheets/observ/application.scss'

// Start Stimulus application
const application = Application.start()
application.debug = false
window.Stimulus = application

// Auto-register all Observ Stimulus controllers
const controllers = import.meta.glob('../controllers/observ/*_controller.js', { eager: true })
registerControllers(application, controllers)
