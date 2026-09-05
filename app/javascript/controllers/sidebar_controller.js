import { Controller } from "@hotwired/stimulus"

// Collapsible sidebar at every breakpoint (not just mobile/tablet) — an
// overlay-with-scrim below the desktop breakpoint, docked-in-flow above it.
// Open/closed is tracked explicitly here rather than left to CSS breakpoint
// defaults, so the toggle button always does something regardless of
// viewport width.
export default class extends Controller {
  static targets = ["panel", "scrim"]

  connect() {
    this.desktopQuery = window.matchMedia("(min-width: 1200px)")
    this.open = this.desktopQuery.matches
    this.desktopQuery.addEventListener("change", this.onBreakpointChange)
    this.render()
  }

  disconnect() {
    this.desktopQuery.removeEventListener("change", this.onBreakpointChange)
  }

  toggle() {
    this.open = !this.open
    this.render()
  }

  close() {
    this.open = false
    this.render()
  }

  onBreakpointChange = (event) => {
    this.open = event.matches
    this.render()
  }

  render() {
    this.panelTarget.classList.toggle("is-open", this.open)
    this.scrimTarget.classList.toggle("is-open", this.open && !this.desktopQuery.matches)
  }
}
