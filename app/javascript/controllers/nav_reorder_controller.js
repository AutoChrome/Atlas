import { Controller } from "@hotwired/stimulus"

// Drag-and-drop reordering for areas in the sidebar. Off by default (plain
// navigation); a toggle button switches into an editing mode where each
// area becomes draggable within its own sibling group (top-level areas
// among themselves, each area's sub-areas among themselves) — dragging
// across groups isn't supported, only reordering within one. Drag-handle
// visibility is pure CSS (.nav-tree--editing), not JS — see components/_nav_tree.scss.
export default class extends Controller {
  static targets = ["item", "list", "toggleButton"]
  static values = { url: String }

  connect() {
    this.editing = false
    this.dragged = null
  }

  toggle() {
    this.editing = !this.editing
    this.element.classList.toggle("nav-tree--editing", this.editing)
    this.itemTargets.forEach((item) => (item.draggable = this.editing))
    this.toggleButtonTarget.classList.toggle("is-active", this.editing)
    this.toggleButtonTarget.setAttribute("aria-pressed", this.editing)
  }

  preventNavigationWhileEditing(event) {
    if (this.editing) event.preventDefault()
  }

  dragStart(event) {
    if (!this.editing) {
      event.preventDefault()
      return
    }
    this.dragged = event.currentTarget
    this.dragged.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.areaId)
  }

  dragOver(event) {
    if (!this.editing || !this.dragged) return

    // Must preventDefault on every dragover while a drag is live, or the
    // browser won't fire `drop` at all for whatever element the cursor
    // happens to be over at mouseup — which, since the dragged element
    // itself gets moved to follow the cursor below, is very often the
    // dragged element itself. Skipping preventDefault there (as this used
    // to) meant most drops silently did nothing: the row visibly moved
    // (that's just the DOM manipulation below, already applied), but the
    // browser cancelled the drop before our fetch() in drop() ever ran, so
    // nothing was saved — exactly the "moved but didn't stick" bug.
    event.preventDefault()

    const target = event.currentTarget
    if (target === this.dragged) return

    // Only reorder within the same sibling group — ignore drags over an
    // item that belongs to a different parent's list.
    if (target.closest('[data-nav-reorder-target="list"]') !== this.dragged.closest('[data-nav-reorder-target="list"]')) {
      return
    }

    const rect = target.getBoundingClientRect()
    const before = event.clientY - rect.top < rect.height / 2
    target.parentNode.insertBefore(this.dragged, before ? target : target.nextSibling)
  }

  async drop(event) {
    event.preventDefault()
    if (!this.dragged) return

    const list = this.dragged.closest('[data-nav-reorder-target="list"]')
    const ids = Array.from(list.querySelectorAll(':scope > [data-nav-reorder-target="item"]')).map(
      (el) => el.dataset.areaId
    )

    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ area_ids: ids }),
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
