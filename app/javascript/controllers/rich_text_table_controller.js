import { Controller } from "@hotwired/stimulus"

// Adds an "Insert table" button to the Trix toolbar, and makes a table
// clickable once it's in the document. Trix has no concept of tables, and
// (see ContentTable for the full story) neither raw HTML insertion nor
// direct in-place cell editing survive Trix's own handling — so a table is
// an ActionText attachment Trix just displays by reference, and "editing"
// it opens a dialog whose content is a normal page fragment, not something
// embedded in the attachment itself.
export default class extends Controller {
  static targets = ["editor", "dialog", "dialogBody"]
  static values = { createUrl: String }

  connect() {
    this.trixElement = this.editorTarget
    if (this.trixElement.editor) {
      this.injectButton()
    } else {
      this.trixElement.addEventListener("trix-initialize", () => this.injectButton(), { once: true })
    }

    this.trixElement.addEventListener("click", (event) => this.handleAttachmentClick(event))
  }

  injectButton() {
    const toolbar = this.trixElement.toolbarElement
    if (!toolbar || toolbar.querySelector(".rich-text-table-button")) return

    const group = document.createElement("span")
    group.className = "trix-button-group"
    group.innerHTML = `
      <button type="button" class="trix-button rich-text-table-button" title="Insert table" tabindex="-1">
        <i class="fa-solid fa-table icon-fa"></i>
      </button>
    `
    toolbar.querySelector(".trix-button-row").appendChild(group)
    group.querySelector("button").addEventListener("click", (event) => {
      event.preventDefault()
      this.insertTable()
    })
  }

  async insertTable() {
    const response = await fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
      },
    })
    const { sgid, content } = await response.json()

    this.trixElement.editor.insertAttachment(new Trix.Attachment({ sgid, content }))
  }

  // The rendered table's only surviving identifying mark, once Trix has
  // sanitized its attachment preview, is a `rich-text-table--<id>` class
  // (see content_tables/_content_table.html.erb) — everything else
  // (data-*, contenteditable) gets stripped, so this is the one channel
  // left to recover which table was clicked.
  handleAttachmentClick(event) {
    const table = event.target.closest("table.rich-text-table")
    if (!table) return

    const idClass = [ ...table.classList ].find((name) => name.startsWith("rich-text-table--"))
    const id = idClass?.split("--")[1]
    if (!id) return

    event.preventDefault()
    this.openEditDialog(id)
  }

  async openEditDialog(id) {
    const response = await fetch(`/content_tables/${id}/edit`, { headers: { Accept: "text/html" } })
    this.dialogBodyTarget.innerHTML = await response.text()
    this.dialogTarget.showModal()
  }

  closeDialog() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.closeDialog()
  }
}
