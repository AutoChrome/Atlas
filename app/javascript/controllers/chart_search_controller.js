import { Controller } from "@hotwired/stimulus"

// Live filter over the table cards — no submit button, reacts to typing
// with a short debounce so it doesn't re-filter on every single keystroke.
// Matching a table's own name or any of its column names shows it
// outright; a table that ONLY matches because it's related (a foreign key
// either direction) to something that matched by name is shown too, but
// grouped after the divider — following a relationship shouldn't mean
// losing sight of what you actually searched for.
export default class extends Controller {
  static targets = ["input", "table", "divider"]

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.applyFilter(), 200)
  }

  applyFilter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    if (!query) {
      this.tableTargets.forEach((el) => {
        el.hidden = false
        el.style.order = ""
      })
      this.setDividerVisible(false)
      return
    }

    const matchedIds = new Set(
      this.tableTargets.filter((el) => el.dataset.searchText.includes(query)).map((el) => el.dataset.chartTableId)
    )

    const relatedIds = new Set()
    this.tableTargets.forEach((el) => {
      if (!matchedIds.has(el.dataset.chartTableId)) return
      this.relatedIdsFor(el).forEach((id) => {
        if (!matchedIds.has(id)) relatedIds.add(id)
      })
    })

    this.tableTargets.forEach((el) => {
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
    })

    this.setDividerVisible(relatedIds.size > 0)
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
