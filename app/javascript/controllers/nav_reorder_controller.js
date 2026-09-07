import { Controller } from "@hotwired/stimulus"

// Personal drag-and-drop reordering for areas in the sidebar. This is
// purely a per-browser preference — saved to localStorage, never sent to
// the server — so anyone can arrange their own sidebar without touching
// what anyone else sees. Off by default (plain navigation); a toggle
// button switches into an editing mode where each area becomes draggable
// within its own sibling group (top-level areas among themselves, each
// area's sub-areas among themselves) — dragging across groups isn't
// supported, only reordering within one. Drag-handle visibility is pure
// CSS (.nav-tree--editing), not JS — see components/_nav_tree.scss.
const STORAGE_KEY = "atlas:areaOrder"

export default class extends Controller {
  static targets = ["item", "list", "toggleButton"]

  connect() {
    this.editing = false
    this.dragged = null
    this.listTargets.forEach((list) => this.applyOrder(list))
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

  drop(event) {
    event.preventDefault()
    if (!this.dragged) return

    const list = this.dragged.closest('[data-nav-reorder-target="list"]')
    const ids = Array.from(list.querySelectorAll(':scope > [data-nav-reorder-target="item"]')).map(
      (el) => el.dataset.areaId
    )

    this.saveOrder(list.dataset.parentId, ids)
    this.dragEnd()
  }

  dragEnd() {
    this.dragged?.classList.remove("is-dragging")
    this.dragged = null
  }

  // Rearranges one list's area items (leaving any interspersed page/chart/
  // tutorial rows untouched) to match a previously-saved order. Areas
  // created since the order was saved aren't in it — they're left in their
  // server-rendered position at the end, rather than disappearing.
  applyOrder(list) {
    const saved = this.loadOrder(list.dataset.parentId)
    if (!saved || saved.length === 0) return

    const items = Array.from(list.querySelectorAll(':scope > [data-nav-reorder-target="item"]'))
    const byId = new Map(items.map((el) => [ el.dataset.areaId, el ]))

    const known = saved.map((id) => byId.get(id)).filter(Boolean)
    const unknown = items.filter((el) => !saved.includes(el.dataset.areaId))

    // appendChild on an element already in the document moves it — doing
    // this in the desired order re-sequences just this trailing block of
    // area items without disturbing the non-area rows before them.
    ;[ ...known, ...unknown ].forEach((el) => list.appendChild(el))
  }

  saveOrder(parentId, ids) {
    const all = this.loadAll()
    all[parentId] = ids
    this.persistAll(all)
  }

  loadOrder(parentId) {
    return this.loadAll()[parentId]
  }

  loadAll() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}
    } catch {
      return {}
    }
  }

  persistAll(all) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(all))
    } catch {
      // Storage disabled/full/private-browsing — the drag still visually
      // reordered this page load, it just won't stick next time.
    }
  }
}
