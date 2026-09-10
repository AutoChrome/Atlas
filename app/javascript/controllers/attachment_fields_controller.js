import { Controller } from "@hotwired/stimulus"

// The page form's attachment picker — a styled drop zone plus a hidden
// native file input for click-to-browse, and support for dropping files
// anywhere on the page (bound at the window level below), not just onto
// the small zone itself, which is easy to miss on a long form.
//
// Adding a file (either way) clones the same accepts_nested_attributes_for
// template nested_fields_controller.js already uses elsewhere in this app
// (tutorial tasks, chart columns) — this doesn't reuse that controller
// directly since a dropped/selected File object also has to be attached to
// the new fieldset's own file input, which needs its own add() rather than
// the generic one.
export default class extends Controller {
  static targets = ["list", "template", "dropOverlay", "fileInput"]

  connect() {
    this.dragDepth = 0
  }

  browse() {
    this.fileInputTarget.click()
  }

  filesSelected(event) {
    this.addFiles(event.target.files)
    // Otherwise picking the exact same file again (e.g. after removing it)
    // wouldn't fire another 'change' event at all.
    event.target.value = ""
  }

  // dragenter/dragleave fire once per element boundary the cursor crosses,
  // not once per drag gesture — even bound at the window level, moving
  // over a heading vs. a paragraph vs. the gap between them each fires its
  // own enter/leave pair. Counting depth (rather than toggling on every
  // event) is the standard fix: only truly "left" once it bottoms out at 0.
  dragEnter(event) {
    event.preventDefault()
    this.dragDepth++
    this.dropOverlayTarget.hidden = false
  }

  // Required on every dragover, not just dragenter — without calling
  // preventDefault() here too, browsers treat this as "not a valid drop
  // target" and either reject the drop outright or navigate to open the
  // file instead of firing a 'drop' event at all.
  dragOver(event) {
    event.preventDefault()
  }

  dragLeave(event) {
    event.preventDefault()
    this.dragDepth = Math.max(0, this.dragDepth - 1)
    if (this.dragDepth === 0) this.dropOverlayTarget.hidden = true
  }

  drop(event) {
    event.preventDefault()
    this.dragDepth = 0
    this.dropOverlayTarget.hidden = true
    this.addFiles(event.dataTransfer.files)
  }

  addFiles(fileList) {
    Array.from(fileList).forEach((file) => this.addFile(file))
  }

  addFile(file) {
    const uniqueId = `${Date.now()}${Math.floor(Math.random() * 1000)}`
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, uniqueId)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    const item = this.listTarget.lastElementChild

    // A plain <input type="file"> can't have its `value` set directly
    // (browsers block that for security) — building a real FileList via
    // DataTransfer and assigning THAT is the standard way to hand a
    // programmatically-obtained File (drag-and-drop or otherwise) to a
    // file input as if the user had picked it themselves.
    const input = item.querySelector('input[type="file"]')
    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    input.files = dataTransfer.files

    const nameField = item.querySelector('[data-attachment-fields-target="downloadFilenameInput"]')
    if (nameField) nameField.placeholder = file.name

    const preview = item.querySelector('[data-attachment-fields-target="previewName"]')
    if (preview) preview.textContent = file.name
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest('[data-attachment-fields-target="item"]')
    const destroyField = item.querySelector('input[name*="[_destroy]"]')

    if (destroyField) {
      // Already persisted — keep it in the form (marked for destruction)
      // so Rails actually deletes it on submit, just hide it from view.
      destroyField.value = "1"
      item.hidden = true
    } else {
      // Never saved — nothing to tell the server to destroy, just drop it.
      item.remove()
    }
  }
}
