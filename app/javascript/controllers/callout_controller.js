import { Controller } from "@hotwired/stimulus"

// Persists edits to a callout embedded in a page's rich text (see Callout,
// rich_text_callout_controller.js, and the editable partial this is
// attached to). Same reasoning as content_table_controller.js: the page's
// own saved rich text only ever holds a reference (this callout's signed
// global ID), never its actual text or type, so every edit has to be
// persisted here directly and promptly.
export default class extends Controller {
  static targets = ["body"]
  static values = { url: String }

  connect() {
    this.saveTimer = null
  }

  disconnect() {
    clearTimeout(this.saveTimer)
  }

  scheduleSave() {
    clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.save(), 500)
  }

  // Used after a variant change rather than a plain text edit — that
  // should stick immediately, not wait out the debounce.
  saveNow() {
    clearTimeout(this.saveTimer)
    this.save()
  }

  setVariant(event) {
    const variant = event.currentTarget.dataset.variant
    this.element.querySelectorAll(".rich-text-callout__variant-button").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.variant === variant)
    })
    this.save({ variant })
  }

  async save(extra = {}) {
    const payload = { body: this.bodyTarget.innerText.trim(), ...extra }

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
      },
      body: JSON.stringify(payload),
    })
  }
}
