import { Controller } from "@hotwired/stimulus"

// Usage: data-controller="modal" directly on the <dialog>, with the trigger
// button inside it (e.g. a menu item that opens itself) — open()/close() act
// on this.element. When the trigger lives outside the dialog (a "+ Add"
// button next to a closed dialog), put data-controller="modal" on a shared
// wrapper around both and mark the dialog itself with data-modal-target="dialog".
export default class extends Controller {
  static targets = ["dialog"]

  get dialog() {
    return this.hasDialogTarget ? this.dialogTarget : this.element
  }

  open() {
    this.dialog.showModal()
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
