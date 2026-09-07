import { Controller } from "@hotwired/stimulus"

// Adds Note/Warning/Tip buttons to the Trix toolbar, and makes a callout
// clickable once it's in the document. See Callout for why this is an
// ActionText attachment rather than a native Trix block type — the
// approach that looked simpler at first (blockquote/heading/code all work
// that way), but doesn't survive Trix re-parsing previously-saved content
// back into the editor, confirmed directly. Structurally this is
// rich_text_table_controller.js's exact pattern: create via fetch, insert
// as an attachment, recover which one was clicked via a class name (the
// one thing Trix's attachment-preview sanitizer leaves alone), edit in a
// dialog that's an ordinary fetched fragment rather than embedded content.
export default class extends Controller {
  static targets = ["editor", "dialog", "dialogBody"]
  static values = { createUrl: String }

  connect() {
    this.trixElement = this.editorTarget
    if (this.trixElement.editor) {
      this.injectButtons()
    } else {
      this.trixElement.addEventListener("trix-initialize", () => this.injectButtons(), { once: true })
    }

    this.trixElement.addEventListener("click", (event) => this.handleAttachmentClick(event))
  }

  injectButtons() {
    const toolbar = this.trixElement.toolbarElement
    if (!toolbar || toolbar.querySelector(".rich-text-callout-group")) return

    const group = document.createElement("span")
    group.className = "trix-button-group rich-text-callout-group"
    group.innerHTML = `
      <button type="button" class="trix-button" data-variant="note" title="Note">
        <i class="fa-solid fa-circle-info icon-fa"></i>
      </button>
      <button type="button" class="trix-button" data-variant="warning" title="Warning">
        <i class="fa-solid fa-triangle-exclamation icon-fa"></i>
      </button>
      <button type="button" class="trix-button" data-variant="tip" title="Tip">
        <i class="fa-solid fa-lightbulb icon-fa"></i>
      </button>
    `
    toolbar.querySelector(".trix-button-row").appendChild(group)
    group.querySelectorAll("button").forEach((button) => {
      button.addEventListener("click", (event) => {
        event.preventDefault()
        this.insertCallout(button.dataset.variant)
      })
    })
  }

  async insertCallout(variant) {
    const response = await fetch(`${this.createUrlValue}?variant=${variant}`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
      },
    })
    const { sgid, content } = await response.json()

    this.trixElement.editor.insertAttachment(new Trix.Attachment({ sgid, content }))
  }

  // The one surviving identifying mark on a callout rendered inside Trix,
  // once its attachment preview has been sanitized, is a
  // `js-callout-id-<id>` class (see callouts/_callout.html.erb).
  handleAttachmentClick(event) {
    const callout = event.target.closest(".rich-text-callout")
    if (!callout) return

    const idClass = [ ...callout.classList ].find((name) => name.startsWith("js-callout-id-"))
    const id = idClass?.replace("js-callout-id-", "")
    if (!id) return

    event.preventDefault()
    this.openEditDialog(id)
  }

  async openEditDialog(id) {
    const response = await fetch(`/callouts/${id}/edit`, { headers: { Accept: "text/html" } })
    this.dialogBodyTarget.innerHTML = await response.text()
    this.dialogTarget.showModal()
  }

  closeDialog() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.closeDialog()
  }

  // callout_controller.js dispatches this (see _rich_text_field.html.erb
  // for the data-action wiring) whenever an edit in the dialog is
  // persisted — same reasoning as rich_text_table_controller.js's
  // refreshAttachment: the dialog is an ordinary page fragment outside
  // Trix's own document, so this is what actually pushes the change into
  // the live attachment instead of leaving it to only show up once the
  // page itself is saved and reloaded.
  refreshAttachment(event) {
    const { id, content } = event.detail
    const marker = `js-callout-id-${id}`

    this.trixElement.editor.getDocument().getAttachments().forEach((attachment) => {
      if (attachment.getContent()?.includes(marker)) attachment.setAttributes({ content })
    })

    // setAttributes above keeps Trix's own document model in sync (what
    // actually gets saved), but unlike an image attachment — which Trix
    // does know how to refresh in place — a "content" attachment's DOM
    // node is only ever built once, at insertion (confirmed directly:
    // the model updates, the rendered callout does not). So the visible
    // node has to be swapped by hand too, or the dialog closing would be
    // the only thing that ever appeared to do anything.
    const rendered = this.trixElement.querySelector(`.${marker}`)
    const template = document.createElement("template")
    template.innerHTML = content
    const replacement = template.content.querySelector(`.${marker}`)
    if (rendered && replacement) rendered.replaceWith(replacement)
  }
}
