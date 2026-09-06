import { Controller } from "@hotwired/stimulus"

// Drag-and-drop reordering for a tutorial's step list. Simpler than
// nav_reorder_controller.js — this only ever renders inside the
// already-editor-gated "Steps" management section, so items are always
// draggable, no separate edit-mode toggle needed.
export default class extends Controller {
  static targets = ["item", "list"]
  static values = { url: String }

  connect() {
    this.dragged = null
  }

  dragStart(event) {
    this.dragged = event.currentTarget
    this.dragged.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.stepId)
  }

  dragOver(event) {
    if (!this.dragged) return
    event.preventDefault()

    const target = event.currentTarget
    if (target === this.dragged) return

    const rect = target.getBoundingClientRect()
    const before = event.clientY - rect.top < rect.height / 2
    target.parentNode.insertBefore(this.dragged, before ? target : target.nextSibling)
  }

  async drop(event) {
    event.preventDefault()
    if (!this.dragged) return

    const ids = Array.from(this.listTarget.querySelectorAll(':scope > [data-tutorial-steps-reorder-target="item"]')).map(
      (el) => el.dataset.stepId
    )

    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ step_ids: ids }),
      })
    } finally {
      this.dragEnd()
    }
  }

  dragEnd() {
    this.dragged?.classList.remove("is-dragging")
    this.dragged = null
  }
}
