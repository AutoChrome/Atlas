import { Controller } from "@hotwired/stimulus"

// Two ways to edit Webhook#custom_parameters_json (see
// admin/webhooks/_form.html.erb): a plain key/value row list for anyone
// who'd rather not hand-write JSON, and the raw textarea underneath it for
// exact control (a number/boolean/null value, or just a preference for
// typing JSON directly) — custom_parameters itself only ever supports flat
// string/number/boolean/null values (see Webhook's own validation), so
// neither view can express anything the other can't hold, only how it's
// entered. Whichever view is active, the textarea is what actually gets
// submitted; the row list has no representation of its own, it just
// serializes itself into that field on every change.
export default class extends Controller {
  static targets = ["pairsView", "list", "template", "textarea", "pairsTab", "jsonTab", "jsonError"]

  // Starts in pairs view whenever the textarea's current content parses as
  // a flat object (a brand new webhook's blank textarea included — that's
  // "{}", which still counts) — a non-string value already saved (say, a
  // number) just gets stringified for display in its row without touching
  // the textarea itself, so nothing is actually lost unless the admin
  // edits a row, which is the same "editing this view stringifies things"
  // trade-off as any other point in the row list's lifetime. Falls back to
  // JSON view only if that content genuinely isn't a flat object at all.
  connect() {
    this.activateTab(this.rebuildRowsFromTextarea() ? this.pairsTabTarget : this.jsonTabTarget)
  }

  addRow(event) {
    event.preventDefault()
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.syncFromPairs()
  }

  removeRow(event) {
    event.preventDefault()
    event.target.closest('[data-key-value-editor-target="row"]').remove()
    this.syncFromPairs()
  }

  syncFromPairs() {
    const pairs = {}
    this.listTarget.querySelectorAll('[data-key-value-editor-target="row"]').forEach((row) => {
      const key = row.querySelector('[data-key-value-editor-target="key"]').value.trim()
      const value = row.querySelector('[data-key-value-editor-target="value"]').value
      if (key) pairs[key] = value
    })
    this.textareaTarget.value = Object.keys(pairs).length ? JSON.stringify(pairs, null, 2) : ""
  }

  showPairs(event) {
    event.preventDefault()
    if (!this.rebuildRowsFromTextarea()) return
    this.activateTab(this.pairsTabTarget)
  }

  showJson(event) {
    event.preventDefault()
    this.syncFromPairs()
    this.activateTab(this.jsonTabTarget)
  }

  // Returns true and rebuilds the row list from the textarea's current
  // contents; returns false and leaves the row list untouched if that
  // content isn't a flat JSON object right now, so switching views never
  // silently discards an edit that doesn't parse yet.
  rebuildRowsFromTextarea() {
    const raw = this.textareaTarget.value.trim()
    let parsed = {}

    if (raw) {
      try {
        parsed = JSON.parse(raw)
      } catch {
        this.jsonErrorTarget.hidden = false
        return false
      }
      if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
        this.jsonErrorTarget.hidden = false
        return false
      }
    }

    this.jsonErrorTarget.hidden = true
    this.listTarget.innerHTML = ""
    const entries = Object.entries(parsed)
    if (entries.length === 0) entries.push([ "", "" ])
    entries.forEach(([ key, value ]) => {
      this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
      const row = this.listTarget.lastElementChild
      row.querySelector('[data-key-value-editor-target="key"]').value = key
      row.querySelector('[data-key-value-editor-target="value"]').value = value === null ? "" : String(value)
    })
    return true
  }

  activateTab(activeTab) {
    const isPairs = activeTab === this.pairsTabTarget
    this.pairsViewTarget.hidden = !isPairs
    this.textareaTarget.hidden = isPairs
    this.pairsTabTarget.classList.toggle("is-active", isPairs)
    this.jsonTabTarget.classList.toggle("is-active", !isPairs)
  }
}
