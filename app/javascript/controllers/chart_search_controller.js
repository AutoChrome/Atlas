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
  static targets = ["input", "table", "divider", "elsewhere"]
  static values = { elsewhereUrl: String }

  connect() {
    this.debounceTimer = null
    this.frameHandle = null
    this.elsewhereAbortController = null
    this.lastElsewhereResults = []
    // The "Also connected to your search" divider covers two independent
    // sources — this chart's own relationship-related tables, and tables
    // found in other charts — computed on different schedules (one's a
    // synchronous local pass, the other a network round trip). Each tracks
    // its own count and both go through updateDividerVisibility so neither
    // one's result overwrites the other's.
    this.lastRelatedCount = 0
    this.lastElsewhereTableCount = 0

    // Every link this controller hands out to a cross-chart hint (see
    // renderElsewhere and applyElsewhereColumnHints) carries the search
    // term as ?q=... (see ChartsController#elsewhere_result) specifically
    // so following it lands here with the SAME search already active —
    // without this, arriving via that link showed a blank search box and
    // none of the OTHER chart's own hints pointing back, which made a
    // genuinely two-way relationship look like it only worked one way.
    const query = new URLSearchParams(window.location.search).get("q")
    if (query) {
      this.inputTarget.value = query
      this.beginFilter()
      this.searchElsewhere()
    }
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    if (this.frameHandle) cancelAnimationFrame(this.frameHandle)
    this.elsewhereAbortController?.abort()
  }

  search() {
    clearTimeout(this.debounceTimer)
    if (this.frameHandle) cancelAnimationFrame(this.frameHandle)

    this.debounceTimer = setTimeout(() => {
      this.frameHandle = requestAnimationFrame(() => this.beginFilter())
      this.searchElsewhere()
    }, 200)
  }

  // A foreign key can point at a table someone organized into a different
  // chart entirely, which this chart's own tables obviously can't surface
  // no matter how the local filter above is tuned. This asks the same
  // Chart search index the sitewide search uses whether the query also
  // matches a table/column name in another chart — a small, independent
  // request (aborting a still-in-flight one on the next keystroke, same
  // idiom as typeahead_controller.js) that never touches this page's own
  // DOM size, so it stays cheap regardless of how large this chart is.
  async searchElsewhere() {
    if (!this.hasElsewhereUrlValue) return

    const query = this.inputTarget.value.trim()
    this.elsewhereAbortController?.abort()

    if (query.length < 2) {
      this.renderElsewhere([])
      return
    }

    this.elsewhereAbortController = new AbortController()

    try {
      const response = await fetch(`${this.elsewhereUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
        signal: this.elsewhereAbortController.signal,
      })
      const data = await response.json()
      this.renderElsewhere(data.results || [])
    } catch (error) {
      if (error.name !== "AbortError") this.renderElsewhere([])
    }
  }

  // The dropdown under the search box is just a quick-jump link list (chart
  // + area name) — the actual table content goes into this chart's own
  // grid instead (see insertElsewhereTables), under the same "Also
  // connected to your search" section as in-chart related tables.
  renderElsewhere(results) {
    this.lastElsewhereResults = results
    this.insertElsewhereTables(results.map((result) => result.tables_html).join(""))
    this.applyElsewhereColumnHints(results)

    if (!this.hasElsewhereTarget) return

    if (results.length === 0) {
      this.elsewhereTarget.innerHTML = ""
      this.hideElsewherePanel()
      return
    }

    this.elsewhereTarget.innerHTML = results
      .map(
        (result) => `
          <a class="chart-search__elsewhere-item" href="${this.escapeHtml(result.url)}">
            <span class="chart-search__elsewhere-chart">${this.escapeHtml(result.chart_title)}</span>
            <span class="chart-search__elsewhere-meta">${this.escapeHtml(result.area_name)}</span>
          </a>
        `
      )
      .join("")
    this.showElsewherePanel()
  }

  // Removes whichever cross-chart preview cards a previous search left in
  // the grid (marked with data-elsewhere-preview — see
  // chart_tables/_preview.html.erb) and inserts the current batch, which
  // already carries its own `order` and source-chart link from the
  // server-rendered partial. The grid element itself isn't a Stimulus
  // target — the divider's own parent is it, and that's already available.
  insertElsewhereTables(tablesHtml) {
    const grid = this.dividerTarget.parentElement
    grid.querySelectorAll("[data-elsewhere-preview]").forEach((el) => el.remove())

    if (tablesHtml) {
      const template = document.createElement("template")
      template.innerHTML = tablesHtml
      this.lastElsewhereTableCount = template.content.children.length
      grid.append(...template.content.children)
    } else {
      this.lastElsewhereTableCount = 0
    }

    this.updateDividerVisibility()
  }

  // A column here can share a name with a column in another chart with no
  // local ChartRelationship to show it — either direction: a plain column
  // here whose actual target (the primary key) lives in a different chart,
  // OR a primary key here whose only pointer lives in a different chart
  // (e.g. a foreign key with nothing to distinguish it locally). Rather
  // than a separate block, this folds straight into the column's own real
  // "Referenced (N)" disclosure (see chart_columns/_column.html.erb) —
  // creating that disclosure from scratch for a column with no real
  // relationships at all, or appending into the existing one alongside its
  // real entries. Clears whatever a previous search injected first, exactly
  // like insertElsewhereTables does for table previews, so an empty
  // `results` array (a cleared/too-short query) removes them rather than
  // leaving stale ones behind — including removing a disclosure this code
  // created itself, once its last hint is gone.
  applyElsewhereColumnHints(results) {
    this.element.querySelectorAll("[data-elsewhere-relationship-hint]").forEach((li) => {
      const details = li.closest(".chart-column__relationships")
      li.remove()
      if (!details) return
      if (details.dataset.elsewhereCreated) {
        details.remove()
      } else {
        this.updateDisclosureSummary(details, "Referenced")
      }
    })

    // A table's own aggregate "Relationships (N)" list (chart_tables/_table)
    // is a second, independent place the exact same hint needs to show up —
    // it's the first thing a user checking "does anything reference this
    // table" looks at, and only listing the hint on the individual column's
    // own disclosure left it invisible there.
    this.element.querySelectorAll("[data-elsewhere-table-relationship-hint]").forEach((li) => {
      const details = li.closest(".chart-table__relationships")
      li.remove()
      if (!details) return
      if (details.dataset.elsewhereCreated) {
        details.remove()
      } else {
        this.updateDisclosureSummary(details, "Relationships")
      }
    })

    const candidatesByColumn = new Map()
    results.forEach((result) => {
      (result.matched_columns || []).forEach((match) => {
        const key = match.name.toLowerCase()
        if (!candidatesByColumn.has(key)) candidatesByColumn.set(key, [])
        candidatesByColumn.get(key).push({ result, primaryKey: match.primary_key })
      })
    })

    if (candidatesByColumn.size === 0) return

    this.element.querySelectorAll(".chart-column[data-column-name]").forEach((columnEl) => {
      const candidates = candidatesByColumn.get(columnEl.dataset.columnName.toLowerCase())
      if (!candidates) return

      // Only a genuine FK/PK-shaped pair — exactly one side a primary key,
      // the other not — is worth surfacing. Two same-named primary keys
      // (nearly every table has its own "id") or two same-named plain
      // columns is far more likely coincidence than an actual relationship.
      const isPrimaryKey = columnEl.dataset.primaryKey === "true"
      const matches = candidates.filter((c) => c.primaryKey !== isPrimaryKey)
      if (matches.length === 0) return

      const icon = '<i class="fa-solid fa-arrow-up-right-from-square icon-fa" aria-hidden="true"></i>'
      const columnName = columnEl.dataset.columnName

      let details = columnEl.querySelector(".chart-column__relationships")
      if (!details) {
        details = document.createElement("details")
        details.className = "chart-column__relationships"
        details.dataset.elsewhereCreated = "true"
        details.innerHTML = '<summary>Referenced (0)</summary><ul class="chart-column__relationships-list"></ul>'
        columnEl.appendChild(details)
      }
      const list = details.querySelector(".chart-column__relationships-list")
      matches.forEach(({ result }) => {
        const li = document.createElement("li")
        li.dataset.elsewhereRelationshipHint = ""
        li.innerHTML = `${icon} <a href="${this.escapeHtml(result.url)}">${this.escapeHtml(result.area_name)} · ${this.escapeHtml(result.chart_title)}</a>`
        list.appendChild(li)
      })
      this.updateDisclosureSummary(details, "Referenced")

      const tableEl = columnEl.closest(".chart-table")
      if (!tableEl) return

      let tableDetails = tableEl.querySelector(".chart-table__relationships")
      if (!tableDetails) {
        tableDetails = document.createElement("details")
        tableDetails.className = "chart-table__relationships"
        tableDetails.dataset.elsewhereCreated = "true"
        tableDetails.innerHTML = '<summary>Relationships (0)</summary><ul class="chart-table__relationships-list"></ul>'
        tableEl.appendChild(tableDetails)
      }
      const tableList = tableDetails.querySelector(".chart-table__relationships-list")
      matches.forEach(({ result }) => {
        const li = document.createElement("li")
        li.dataset.elsewhereTableRelationshipHint = ""
        li.innerHTML = `<strong>${this.escapeHtml(columnName)}</strong> ${icon} <a href="${this.escapeHtml(result.url)}">${this.escapeHtml(result.area_name)} · ${this.escapeHtml(result.chart_title)}</a>`
        tableList.appendChild(li)
      })
      this.updateDisclosureSummary(tableDetails, "Relationships")
    })
  }

  updateDisclosureSummary(details, label) {
    const count = details.querySelectorAll("li").length
    details.querySelector("summary").textContent = `${label} (${count})`
  }

  // Re-opens the panel with whatever was last found, without re-fetching —
  // clicking back into the search box after having dismissed it (see
  // closeElsewhereOnOutsideClick) should feel instant, not re-run a search.
  openElsewhere() {
    if (this.lastElsewhereResults.length > 0) this.showElsewherePanel()
  }

  // "Click on the background" dismisses the panel until the search box is
  // used again — bound to click@document (see the view) so this fires for
  // a click anywhere on the page, not just within this controller's own
  // element (which is the whole chart page, grid included).
  closeElsewhereOnOutsideClick(event) {
    if (!event.target.closest(".chart-search")) this.hideElsewherePanel()
  }

  showElsewherePanel() {
    if (this.hasElsewhereTarget) this.elsewhereTarget.hidden = false
  }

  hideElsewherePanel() {
    if (this.hasElsewhereTarget) this.elsewhereTarget.hidden = true
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
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
        this.lastRelatedCount = 0
        this.updateDividerVisibility()
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
        this.lastRelatedCount = relatedIds.size
        this.updateDividerVisibility()
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

  updateDividerVisibility() {
    if (!this.hasDividerTarget) return
    this.dividerTarget.hidden = !(this.lastRelatedCount > 0 || this.lastElsewhereTableCount > 0)
    this.dividerTarget.style.order = "1"
  }
}
