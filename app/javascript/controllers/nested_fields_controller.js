import { Controller } from "@hotwired/stimulus"

// Generic Rails `accepts_nested_attributes_for` add/remove, entirely
// client-side — appending a fieldset (or marking one for destruction) never
// touches the server, so a form can hold as many nested tasks/choices as
// the author wants before the parent record is ever saved. One controller
// instance per nested collection (tasks, choices, ...) on a page, since
// `template`/`list` are scoped per instance.
//
// The template's own fields must use "NEW_RECORD" in place of the real
// index (e.g. `tutorial_step[tutorial_tasks_attributes][NEW_RECORD][description]`)
// — `add` replaces every occurrence with a fresh unique value per clone.
export default class extends Controller {
  static targets = ["template", "list"]

  add(event) {
    event.preventDefault()
    const uniqueId = `${Date.now()}${Math.floor(Math.random() * 1000)}`
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, uniqueId)
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest('[data-nested-fields-target="item"]')
    const destroyField = item.querySelector('input[name*="[_destroy]"]')

    if (destroyField) {
      // Already persisted — keep it in the form (marked for destruction) so
      // Rails actually deletes it on submit, just hide it from view.
      destroyField.value = "1"
      item.hidden = true
    } else {
      // Never saved — nothing to tell the server to destroy, just drop it.
      item.remove()
    }
  }
}
