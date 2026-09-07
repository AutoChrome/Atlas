import { Controller } from "@hotwired/stimulus"

// Miller-column-style sidebar: only one "level" is visible at a time — the
// root's top-level areas, or one specific area's own pages/charts/
// tutorials/sub-areas — instead of an ever-growing indented tree where
// every level nests inside the last and the text gets cramped. Drilling
// into an area swaps to its own level (see shared/_area_nav_level.html.erb,
// one panel per area that has anything in it); the back button returns to
// whichever level is that panel's own parent, so backing out of several
// levels of drilling retraces them one at a time, same as it went in.
//
// Each level panel's identity and its reorder-list identity (see
// nav_reorder_controller.js) are the same value on purpose — "which area's
// children does this list represent" is exactly what both need to know —
// so this reuses data-parent-id rather than adding a second, redundant
// attribute. data-back-to is the only piece unique to this controller: the
// *parent's* id, not this level's own.
export default class extends Controller {
  static targets = ["level"]
  static values = { current: String }

  connect() {
    this.showLevel(this.hasCurrentValue && this.currentValue ? this.currentValue : "root")
  }

  drillInto(event) {
    const item = event.currentTarget.closest("[data-area-id]")
    this.showLevel(item.dataset.areaId)
  }

  back(event) {
    const level = event.currentTarget.closest('[data-nav-drilldown-target="level"]')
    this.showLevel(level.dataset.backTo)
  }

  showLevel(areaId) {
    this.levelTargets.forEach((level) => {
      level.hidden = level.dataset.parentId !== areaId
    })
  }
}
