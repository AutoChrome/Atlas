import { Controller } from "@hotwired/stimulus"

// Persists edits to a table embedded in a page's rich text (see
// ContentTable, rich_text_table_controller.js, and the editable partial
// this is attached to). Cells are ordinary contenteditable elements nested
// inside Trix's own non-editable attachment wrapper, so typing into one
// never goes through Trix's document model or its save cycle at all — the
// page's own saved rich text only ever holds a reference (this table's
// signed global ID), never its actual cell text, so every edit here has to
// be persisted directly and promptly, not carried along by "save the page"
// the way ordinary text would be.
export default class extends Controller {
  static targets = ["table"]
  static values = { url: String }

  connect() {
    this.saveTimer = null
  }

  disconnect() {
    clearTimeout(this.saveTimer)
  }

  scheduleSave() {
    clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.save(), 500)
  }

  // Used after a structural change (add row/column) rather than a plain
  // text edit — those should stick immediately, not wait out the debounce.
  saveNow() {
    clearTimeout(this.saveTimer)
    this.save()
  }

  addRow() {
    const table = this.tableTarget
    const columnCount = table.querySelector("tr")?.children.length || 1
    const row = document.createElement("tr")
    row.innerHTML = Array.from(
      { length: columnCount },
      () => '<td contenteditable="true" data-action="input->content-table#scheduleSave blur->content-table#saveNow"> </td>'
    ).join("")
    table.querySelector("tbody").appendChild(row)
    this.saveNow()
  }

  addColumn() {
    const table = this.tableTarget
    table.querySelectorAll("tr").forEach((row, index) => {
      const cell = document.createElement(index === 0 ? "th" : "td")
      cell.contentEditable = "true"
      cell.textContent = " "
      cell.setAttribute("data-action", "input->content-table#scheduleSave blur->content-table#saveNow")
      row.appendChild(cell)
    })
    this.saveNow()
  }

  async save() {
    const rows = Array.from(this.tableTarget.querySelectorAll("tr")).map((row) =>
      Array.from(row.children).map((cell) => cell.textContent.trim())
    )

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
      },
      body: JSON.stringify({ content_table: { data: JSON.stringify(rows) } }),
    })
    if (!response.ok) return

    // The dialog editing this table lives outside Trix's own document, so
    // saving here doesn't touch what Trix has cached as the attachment's
    // preview — bubbles up to rich_text_table_controller.js (see
    // _rich_text_field.html.erb), which is the one with access to the live
    // Trix editor, to push the fresh HTML into it. Without this, the page
    // keeps showing the table as it looked when it was first inserted until
    // the whole page is saved and reloaded.
    const { id, content } = await response.json()
    this.dispatch("saved", { detail: { id, content } })
  }
}
