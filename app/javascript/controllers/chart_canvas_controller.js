import { Controller } from "@hotwired/stimulus"

// Freeform ERD whiteboard: absolutely-positioned table nodes inside a
// position:relative content box, connected by an SVG overlay sharing that
// same coordinate space. No zoom/pan — a big overflow:auto surface, same
// idea as .kanban-board's overflow-x:auto, just in two dimensions.
//
// Unlike nav-reorder/roadmap-*'s native HTML5 drag-and-drop (which only
// ever reorders DOM siblings), this tracks continuous x/y via Pointer
// Events — there is no "insert before/after a sibling" here, just a
// stored pixel position persisted on drag end.
export default class extends Controller {
  static targets = ["content", "svg", "table", "connector"]
  static values = { relationshipsUrl: String }

  connect() {
    this.dragging = null
    this.connecting = null
    this.redrawScheduled = false
    this.redrawAll()
  }

  // ---- Dragging a table node ------------------------------------------

  startDragTable(event) {
    if (event.target.closest("button, a, dialog")) return // don't hijack header controls

    const table = event.currentTarget.closest('[data-chart-canvas-target="table"]')
    event.preventDefault()
    event.currentTarget.setPointerCapture(event.pointerId)

    this.dragging = {
      table,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      originLeft: parseFloat(table.style.left) || 0,
      originTop: parseFloat(table.style.top) || 0,
    }
    table.classList.add("is-dragging")

    this.element.addEventListener("pointermove", this.dragTableBound ??= this.dragTable.bind(this))
    this.element.addEventListener("pointerup", this.endDragTableBound ??= this.endDragTable.bind(this))
  }

  dragTable(event) {
    if (!this.dragging || event.pointerId !== this.dragging.pointerId) return

    // Deltas in screen pixels are scroll-invariant — no need to touch the
    // canvas's own scroll position here, only the SVG redraw needs that.
    const dx = event.clientX - this.dragging.startX
    const dy = event.clientY - this.dragging.startY
    this.dragging.table.style.left = `${Math.max(0, this.dragging.originLeft + dx)}px`
    this.dragging.table.style.top = `${Math.max(0, this.dragging.originTop + dy)}px`

    this.scheduleRedraw()
  }

  async endDragTable(event) {
    if (!this.dragging || event.pointerId !== this.dragging.pointerId) return
    const { table } = this.dragging
    table.classList.remove("is-dragging")
    this.dragging = null

    try {
      await fetch(table.dataset.repositionUrl, {
        method: "PATCH",
        headers: this.jsonHeaders(),
        body: JSON.stringify({
          chart_table: {
            position_x: Math.round(parseFloat(table.style.left)),
            position_y: Math.round(parseFloat(table.style.top)),
          },
        }),
      })
    } catch (error) {
      // Best-effort — the canvas already reflects the new position locally.
    }
  }

  // ---- Redrawing relationship lines ------------------------------------

  scheduleRedraw() {
    if (this.redrawScheduled) return
    this.redrawScheduled = true
    requestAnimationFrame(() => {
      this.redrawScheduled = false
      this.redrawAll()
    })
  }

  redrawAll() {
    const contentRect = this.contentTarget.getBoundingClientRect()
    this.svgTarget.querySelectorAll("[data-relationship-id]").forEach((path) => {
      const from = this.anchorPoint(path.dataset.fromColumnId, contentRect)
      const to = this.anchorPoint(path.dataset.toColumnId, contentRect)
      if (from && to) path.setAttribute("d", this.curve(from, to))
    })
  }

  // Both the table nodes and the SVG overlay are absolutely positioned
  // inside contentTarget (position: relative), so subtracting its own
  // rect from a connector dot's rect gives content-relative coordinates
  // that stay correct regardless of scroll position.
  anchorPoint(columnId, contentRect) {
    const dot = this.connectorTargets.find((el) => el.dataset.columnId === columnId)
    if (!dot) return null
    const rect = dot.getBoundingClientRect()
    return {
      x: rect.left + rect.width / 2 - contentRect.left,
      y: rect.top + rect.height / 2 - contentRect.top,
    }
  }

  curve(from, to) {
    if (from.x === to.x && from.y === to.y) {
      return `M ${from.x} ${from.y} C ${from.x + 60} ${from.y - 40}, ${from.x + 60} ${from.y + 40}, ${to.x} ${to.y}`
    }
    const midX = (from.x + to.x) / 2
    return `M ${from.x} ${from.y} C ${midX} ${from.y}, ${midX} ${to.y}, ${to.x} ${to.y}`
  }

  // ---- Drawing a new connection (optimistic) ---------------------------

  startConnection(event) {
    event.preventDefault()
    event.stopPropagation() // don't also trigger startDragTable on the table underneath
    event.currentTarget.setPointerCapture(event.pointerId)

    const tempLine = document.createElementNS("http://www.w3.org/2000/svg", "path")
    tempLine.classList.add("chart-relationship", "chart-relationship--pending")
    this.svgTarget.appendChild(tempLine)
    this.connecting = { pointerId: event.pointerId, fromEl: event.currentTarget, tempLine }

    this.element.addEventListener("pointermove", this.dragConnectionBound ??= this.dragConnection.bind(this))
    this.element.addEventListener("pointerup", this.endConnectionBound ??= this.endConnection.bind(this))
  }

  dragConnection(event) {
    if (!this.connecting || event.pointerId !== this.connecting.pointerId) return
    const contentRect = this.contentTarget.getBoundingClientRect()
    const from = this.anchorPoint(this.connecting.fromEl.dataset.columnId, contentRect)
    const to = { x: event.clientX - contentRect.left, y: event.clientY - contentRect.top }
    if (from) this.connecting.tempLine.setAttribute("d", this.curve(from, to))
  }

  async endConnection(event) {
    if (!this.connecting || event.pointerId !== this.connecting.pointerId) return
    const { fromEl, tempLine } = this.connecting
    this.connecting = null
    tempLine.remove()

    const toEl = document
      .elementFromPoint(event.clientX, event.clientY)
      ?.closest('[data-chart-canvas-target="connector"]')
    if (!toEl || toEl === fromEl) return

    let response
    try {
      response = await fetch(this.relationshipsUrlValue, {
        method: "POST",
        headers: this.jsonHeaders(),
        body: JSON.stringify({
          chart_relationship: {
            from_chart_column_id: fromEl.dataset.columnId,
            to_chart_column_id: toEl.dataset.columnId,
          },
        }),
      })
    } catch (error) {
      return
    }
    if (!response.ok) return

    const { id } = await response.json()
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.classList.add("chart-relationship")
    path.dataset.relationshipId = id
    path.dataset.fromColumnId = fromEl.dataset.columnId
    path.dataset.toColumnId = toEl.dataset.columnId
    this.svgTarget.appendChild(path)
    this.redrawAll()

    // The new line has no delete handler wired up until the page is next
    // loaded from the server (which is what renders data-delete-url) — a
    // reload picks up the "click a line to delete it" affordance for it.
  }

  // ---- Deleting a relationship by clicking its line ---------------------

  async deleteRelationship(event) {
    const path = event.currentTarget
    if (!window.confirm("Delete this relationship?")) return

    try {
      await fetch(path.dataset.deleteUrl, {
        method: "DELETE",
        headers: this.jsonHeaders(),
      })
      path.remove()
    } catch (error) {
      // Leave the line in place if the request failed.
    }
  }

  jsonHeaders() {
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
    }
  }
}
