import { Controller } from "@hotwired/stimulus"

// Shows/hides the area checklist on the new-token form depending on
// whether "Access to all areas" is checked.
export default class extends Controller {
  static targets = ["allAreas", "areaList"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.areaListTarget.hidden = this.allAreasTarget.checked
  }
}
