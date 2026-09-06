import { Controller } from "@hotwired/stimulus"

// Opens the native date picker on click (Chrome only does this for the
// calendar icon by default, not the field itself), and keeps the end date's
// minimum in sync with the start date so the picker won't offer anything
// earlier — same day as the start is still allowed, that's how a one-day
// announcement is expressed.
export default class extends Controller {
  static targets = ["start", "end"]

  connect() {
    this.syncMin()
  }

  syncMin() {
    if (this.hasStartTarget && this.hasEndTarget && this.startTarget.value) {
      this.endTarget.min = this.startTarget.value
    }
  }

  openPicker(event) {
    if (typeof event.target.showPicker !== "function") return

    try {
      event.target.showPicker()
    } catch {
      // Some browsers refuse to show it programmatically outside a direct
      // user gesture — clicking still focuses the field normally either way.
    }
  }
}
