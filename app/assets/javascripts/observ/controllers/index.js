// Auto-generated index file for Observ Stimulus controllers
// Register all Observ controllers with the observ-- prefix
//
// This file is designed to be imported by the host application's Stimulus setup.
// The host app should import this file in their controllers/index.js:
//   import "./observ"

import AutoscrollController from "./autoscroll_controller.js"
import ChatFormController from "./chat_form_controller.js"
import CopyController from "./copy_controller.js"
import DashboardController from "./dashboard_controller.js"
import DrawerController from "./drawer_controller.js"
import ExpandableController from "./expandable_controller.js"
import FilterController from "./filter_controller.js"
import JsonViewerController from "./json_viewer_controller.js"
import MessageFormController from "./message_form_controller.js"
import PromptVariablesController from "./prompt_variables_controller.js"
import TextSelectController from "./text_select_controller.js"

// Export controllers for manual registration if needed
export {
  AutoscrollController,
  ChatFormController,
  CopyController,
  DashboardController,
  DrawerController,
  ExpandableController,
  FilterController,
  JsonViewerController,
  MessageFormController,
  PromptVariablesController,
  TextSelectController
}

// Auto-register if Stimulus application is available globally
if (typeof window.Stimulus !== "undefined") {
  const application = window.Stimulus
  
  application.register("observ--autoscroll", AutoscrollController)
  application.register("observ--chat-form", ChatFormController)
  application.register("observ--copy", CopyController)
  application.register("observ--dashboard", DashboardController)
  application.register("observ--drawer", DrawerController)
  application.register("observ--expandable", ExpandableController)
  application.register("observ--filter", FilterController)
  application.register("observ--json-viewer", JsonViewerController)
  application.register("observ--message-form", MessageFormController)
  application.register("observ--prompt-variables", PromptVariablesController)
  application.register("observ--text-select", TextSelectController)
  
  console.log("Observ Stimulus controllers registered")
}
