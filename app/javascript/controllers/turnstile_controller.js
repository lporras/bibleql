import { Controller } from "@hotwired/stimulus"

// Renders a Cloudflare Turnstile widget explicitly, so it also works after Turbo navigation
// (implicit rendering only scans the page once, when the script first loads). The widget adds a
// hidden `cf-turnstile-response` input to the enclosing form, which the server verifies.
const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let scriptPromise

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile)

  scriptPromise ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT_URL
    script.async = true
    script.onload = () => resolve(window.turnstile)
    script.onerror = () => {
      scriptPromise = null
      reject(new Error("Failed to load Cloudflare Turnstile"))
    }
    document.head.appendChild(script)
  })
  return scriptPromise
}

export default class extends Controller {
  static values = { siteKey: String, action: String }

  async connect() {
    try {
      const turnstile = await loadTurnstile()
      if (!this.element.isConnected) return
      this.widgetId = turnstile.render(this.element, { sitekey: this.siteKeyValue, action: this.actionValue })
    } catch (error) {
      console.error(error)
    }
  }

  disconnect() {
    if (this.widgetId !== undefined && window.turnstile) {
      window.turnstile.remove(this.widgetId)
      this.widgetId = undefined
    }
  }
}
