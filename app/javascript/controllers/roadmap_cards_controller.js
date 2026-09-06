import { Controller } from "@hotwired/stimulus"

// Drag-and-drop for cards between (and within) a project's kanban columns.
// Unlike nav-reorder/roadmap-sections, moves ACROSS lists are the whole
// point here, so there's no same-list restriction — dragOver freely
// reparents the dragged card into whichever column it's currently hovering
// over, and drop() persists that column's final card order in one request,
// covering both "reordered within a column" and "moved to a new one".
// Always active (no edit-mode gate) — cards are the routine, frequent thing
// to rearrange, unlike the rarer structural change of adding/reordering columns.
export default class extends Controller {
  static targets = ["card", "list"]
  static values = { moveUrl: String }

  connect() {
    this.dragged = null
  }

  dragStart(event) {
    this.dragged = event.currentTarget
    this.dragged.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.cardId)
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

  // Fires when dragging over a column's card list itself (empty space below
  // the last card, or an empty column) rather than over another card.
  dragOverList(event) {
    if (!this.dragged) return
    event.preventDefault()

    const list = event.currentTarget
    if (this.dragged.parentNode !== list) list.appendChild(this.dragged)
  }

  async drop(event) {
    event.preventDefault()
    if (!this.dragged) return

    const list = this.dragged.closest('[data-roadmap-cards-target="list"]')
    const cardIds = Array.from(list.querySelectorAll(':scope > [data-roadmap-cards-target="card"]')).map(
      (el) => el.dataset.cardId
    )

    try {
      await fetch(this.moveUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ roadmap_section_id: list.dataset.sectionId, card_ids: cardIds }),
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
