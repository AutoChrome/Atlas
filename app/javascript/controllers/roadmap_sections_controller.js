import { Controller } from "@hotwired/stimulus"

// Drag-and-drop reordering for a project's roadmap columns (sections). Off
// by default; the "Edit layout" toggle switches into an editing mode where
// columns become draggable — mirrors nav_reorder_controller.js, but there's
// only ever one list here (a single project's sections), so no same-group
// restriction is needed. Columns are laid out horizontally, so positioning
// uses clientX/left/width rather than nav-reorder's vertical clientY/top/height.
export default class extends Controller {
  static targets = ["column", "list", "toggleButton"]
  static values = { url: String }

  connect() {
    this.editing = false
    this.dragged = null
  }

  toggle() {
    this.editing = !this.editing
    this.element.classList.toggle("kanban-board--editing", this.editing)
    this.columnTargets.forEach((column) => (column.draggable = this.editing))
    this.toggleButtonTarget.classList.toggle("is-active", this.editing)
    this.toggleButtonTarget.setAttribute("aria-pressed", this.editing)
  }

  dragStart(event) {
    if (!this.editing) {
      event.preventDefault()
      return
    }
    this.dragged = event.currentTarget
    this.dragged.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.sectionId)
  }

  dragOver(event) {
    if (!this.editing || !this.dragged) return

    // See nav_reorder_controller.js for why preventDefault must run on every
    // dragover, not just once — otherwise the browser cancels the eventual drop.
    event.preventDefault()

    const target = event.currentTarget
    if (target === this.dragged) return

    const rect = target.getBoundingClientRect()
    const before = event.clientX - rect.left < rect.width / 2
    target.parentNode.insertBefore(this.dragged, before ? target : target.nextSibling)
  }

  async drop(event) {
    event.preventDefault()
    if (!this.dragged) return

    const ids = Array.from(this.listTarget.querySelectorAll(':scope > [data-roadmap-sections-target="column"]')).map(
      (el) => el.dataset.sectionId
    )

    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ section_ids: ids }),
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
