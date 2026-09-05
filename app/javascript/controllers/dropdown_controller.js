import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    document.addEventListener("click", this.close, { once: true })
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.menuTarget.hidden = true
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown = (event) => {
    if (event.key === "Escape") this.close()
  }
}
