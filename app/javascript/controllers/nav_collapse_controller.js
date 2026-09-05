import { Controller } from "@hotwired/stimulus"

// One instance per area row that has children (sub-areas and/or pages).
// Initial expanded/collapsed state is decided server-side (see
// ApplicationController#expanded_area_ids — expanded when the area you're
// currently viewing is this area or one of its descendants); this
// controller only handles the manual toggle from there.
export default class extends Controller {
  static targets = ["children"]

  toggle() {
    this.childrenTarget.hidden = !this.childrenTarget.hidden
    this.element.classList.toggle("is-expanded", !this.childrenTarget.hidden)
  }
}
