import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open() {
    this.element.showModal()
  }

  close() {
    this.element.close()
  }

  // Close when clicking the ::backdrop (a click landing on the <dialog>
  // element itself, outside its content box).
  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }
}
