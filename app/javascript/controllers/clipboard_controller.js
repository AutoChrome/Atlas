import { Controller } from "@hotwired/stimulus"

// Share buttons: copy a URL to the clipboard, briefly confirm it worked.
export default class extends Controller {
  static targets = ["label"]
  static values = { text: String, confirm: { type: String, default: "Copied!" } }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash(this.confirmValue)
    } catch (error) {
      this.flash("Couldn't copy")
    }
  }

  flash(message) {
    if (!this.hasLabelTarget) return

    this.originalLabel ??= this.labelTarget.textContent
    this.labelTarget.textContent = message
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.labelTarget.textContent = this.originalLabel
    }, 1500)
  }
}
