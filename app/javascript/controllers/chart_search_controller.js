import { Controller } from "@hotwired/stimulus"

// Live filter over the table cards — no submit button, reacts to typing
// with a short debounce so it doesn't re-filter on every single keystroke.
// Matching a table's own name or any of its column names shows it
// outright; a table that ONLY matches because it's related (a foreign key
// either direction) to something that matched by name is shown too, but
// grouped after the divider — following a relationship shouldn't mean
// losing sight of what you actually searched for.
//
// A chart with hundreds of tables makes the actual DOM-mutation pass (the
// `hidden`/`order` flip on every card) big enough to visibly block the
// main thread — on a large enough chart, typing could make the tab look
// frozen for a moment. Two things fix that, matching the general
// "skeleton + background" pattern: (1) a "searching" indicator is applied
// on the *next* animation frame after the debounce fires, so the browser
// actually gets to paint it before any of the heavier work starts, rather
// than both landing in the same blocked task; (2) the mutation pass itself
// is chunked across animation frames so a single frame never does more
// than CHUNK_SIZE cards' worth of writes — the tab stays scrollable and
// keeps taking keystrokes throughout, even mid-search on a very large chart.
const CHUNK_SIZE = 40

export default class extends Controller {
  static targets = ["input", "table", "divider"]

  connect() {
    this.debounceTimer = null
    this.frameHandle = null
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    if (this.frameHandle) cancelAnimationFrame(this.frameHandle)
  }

  search() {
    clearTimeout(this.debounceTimer)
    if (this.frameHandle) cancelAnimationFrame(this.frameHandle)

    this.debounceTimer = setTimeout(() => {
      this.frameHandle = requestAnimationFrame(() => this.beginFilter())
    }, 200)
  }

  beginFilter() {
    this.element.classList.add("chart-page--searching")

    // A second frame boundary: the class above has to actually get
    // painted before the (possibly chunky) work below starts, or the
    // "searching" state and that work would land in the same task and the
    // former would never be visible.
    const query = this.inputTarget.value.trim().toLowerCase()
    this.frameHandle = requestAnimationFrame(() => this.applyFilter(query))
  }

  applyFilter(query) {
    const tables = this.tableTargets

    if (!query) {
      tables.forEach((el) => {
        el.hidden = false
        el.style.order = ""
      })
      this.setDividerVisible(false)
      this.finishFilter()
      return
    }

    const matchedIds = new Set(
      tables.filter((el) => el.dataset.searchText.includes(query)).map((el) => el.dataset.chartTableId)
    )

    const relatedIds = new Set()
    tables.forEach((el) => {
      if (!matchedIds.has(el.dataset.chartTableId)) return
      this.relatedIdsFor(el).forEach((id) => {
        if (!matchedIds.has(id)) relatedIds.add(id)
      })
    })

    this.applyVisibility(tables, 0, matchedIds, relatedIds)
  }

  // Flips hidden/order on up to CHUNK_SIZE cards, then yields to the
  // browser via requestAnimationFrame before continuing with the rest.
  applyVisibility(tables, start, matchedIds, relatedIds) {
    const end = Math.min(start + CHUNK_SIZE, tables.length)

    for (let i = start; i < end; i++) {
      const el = tables[i]
      const id = el.dataset.chartTableId
      if (matchedIds.has(id)) {
        el.hidden = false
        el.style.order = "0"
      } else if (relatedIds.has(id)) {
        el.hidden = false
        el.style.order = "2"
      } else {
        el.hidden = true
      }
    }

    if (end < tables.length) {
      this.frameHandle = requestAnimationFrame(() => this.applyVisibility(tables, end, matchedIds, relatedIds))
    } else {
      this.setDividerVisible(relatedIds.size > 0)
      this.finishFilter()
    }
  }

  finishFilter() {
    this.element.classList.remove("chart-page--searching")
  }

  relatedIdsFor(el) {
    return (el.dataset.relatedTableIds || "").split(",").filter(Boolean)
  }

  setDividerVisible(visible) {
    if (!this.hasDividerTarget) return
    this.dividerTarget.hidden = !visible
    this.dividerTarget.style.order = "1"
  }
}
