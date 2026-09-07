import { Controller } from "@hotwired/stimulus"

// Live filter over the table cards — no submit button, reacts to typing
// with a short debounce so it doesn't re-filter on every single keystroke.
// Matching a table's own name or any of its column names shows it
// outright; a table that ONLY matches because it's related (a foreign key
// either direction) to something that matched by name is shown too, but
// grouped after the divider — following a relationship shouldn't mean
// losing sight of what you actually searched for.
//
// A chart with a lot of tables makes this real work: computing matches AND
// flipping hidden/order on every card. An earlier version of this file
// split that into fixed-size batches (e.g. "40 cards, then yield a frame")
// on the theory that yielding between batches keeps the tab responsive.
// It doesn't, reliably — a *fixed item count* per batch only stays under a
// frame budget if you already know how expensive each item is, and on a
// big enough chart (or a slower machine) it doesn't: Chrome's own
// performance panel showed keystrokes with ~13ms of actual processing
// stuck behind ~13 SECONDS of input delay, meaning a train of overrunning
// "batches" had queued up ahead of the keystroke even though each one was
// technically yielding in between.
//
// runChunked below fixes that by chunking on a *time budget* instead of a
// count: do real work until FRAME_BUDGET_MS has elapsed, however many (or
// few) items that turns out to be, then yield a frame and continue. This
// self-adjusts to whatever the actual per-item cost is on whatever
// hardware/chart size it's running against, instead of guessing.
const FRAME_BUDGET_MS = 8

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
    // painted before the (possibly slow) work below starts, or the
    // "searching" state and that work would land in the same task and the
    // former would never be visible.
    const query = this.inputTarget.value.trim().toLowerCase()
    this.frameHandle = requestAnimationFrame(() => this.applyFilter(query))
  }

  applyFilter(query) {
    const tables = this.tableTargets

    if (!query) {
      this.runChunked(tables, (el) => {
        el.hidden = false
        el.style.order = ""
      }, () => {
        this.setDividerVisible(false)
        this.finishFilter()
      })
      return
    }

    const matchedIds = new Set()
    this.runChunked(
      tables,
      (el) => {
        if (el.dataset.searchText.includes(query)) matchedIds.add(el.dataset.chartTableId)
      },
      () => this.computeRelated(tables, query, matchedIds)
    )
  }

  computeRelated(tables, query, matchedIds) {
    const relatedIds = new Set()
    this.runChunked(
      tables,
      (el) => {
        if (!matchedIds.has(el.dataset.chartTableId)) return
        this.relatedIdsFor(el).forEach((id) => {
          if (!matchedIds.has(id)) relatedIds.add(id)
        })
      },
      () => this.applyVisibility(tables, matchedIds, relatedIds)
    )
  }

  applyVisibility(tables, matchedIds, relatedIds) {
    this.runChunked(
      tables,
      (el) => {
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
      },
      () => {
        this.setDividerVisible(relatedIds.size > 0)
        this.finishFilter()
      }
    )
  }

  // Runs `work(item)` over every item in `items`, spending at most
  // FRAME_BUDGET_MS per animation frame before yielding and continuing on
  // the next one, then calls `done`. Stores the pending frame on
  // `this.frameHandle` so search()/disconnect() can cancel a run that's
  // still mid-flight when a new keystroke or a page change comes in.
  runChunked(items, work, done) {
    let index = 0

    const step = () => {
      const deadline = performance.now() + FRAME_BUDGET_MS
      while (index < items.length && performance.now() < deadline) {
        work(items[index])
        index++
      }

      if (index < items.length) {
        this.frameHandle = requestAnimationFrame(step)
      } else {
        done()
      }
    }

    step()
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
