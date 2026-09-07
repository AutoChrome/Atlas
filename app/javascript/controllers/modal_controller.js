import { Controller } from "@hotwired/stimulus"

// Usage: data-controller="modal" directly on the <dialog>, with the trigger
// button inside it (e.g. a menu item that opens itself) — open()/close() act
// on this.element. When the trigger lives outside the dialog (a "+ Add"
// button next to a closed dialog), put data-controller="modal" on a shared
// wrapper around both and mark the dialog itself with data-modal-target="dialog".
//
// Optionally lazy: add data-modal-src-value with a URL and leave the
// <dialog> empty in the markup — its content is fetched (once, then
// cached for the rest of the page's life) the first time it's opened,
// instead of being rendered up front. This matters at scale: a chart with
// hundreds of tables was eagerly rendering one of these per column (a full
// edit form — its own <dialog>, <form>, and every field) whether or not
// anyone ever opened it, which was by far the single biggest contributor
// to a large chart's page weight and load time.
export default class extends Controller {
  static targets = ["dialog"]
  static values = { src: String }

  get dialog() {
    return this.hasDialogTarget ? this.dialogTarget : this.element
  }

  async open() {
    if (this.hasSrcValue && !this.loaded) {
      await this.load()
    }
    this.dialog.showModal()
  }

  async load() {
    const response = await fetch(this.srcValue, { headers: { Accept: "text/html" } })
    this.dialog.innerHTML = await response.text()
    this.loaded = true
  }

  close() {
    this.dialog.close()
  }

  // Close when clicking the ::backdrop (a click landing on the <dialog>
  // element itself, outside its content box).
  closeOnBackdrop(event) {
    if (event.target === this.dialog) this.close()
  }
}
