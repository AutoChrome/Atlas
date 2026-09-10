import { Controller } from "@hotwired/stimulus"

// Wired onto every cell (see _editable.html.erb, and insertRow/insertColumn
// below for cells created after load) — kept as one constant so a cell
// built at any point in the table's life gets the exact same behavior.
const CELL_ACTIONS = "input->content-table#scheduleSave blur->content-table#saveNow paste->content-table#paste"

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

  // Used after a structural change (add/remove row/column, a paste) rather
  // than a plain text edit — those should stick immediately, not wait out
  // the debounce.
  saveNow() {
    clearTimeout(this.saveTimer)
    this.save()
  }

  // Pasting a comma- or pipe-separated block (copied from a spreadsheet, a
  // CSV, a Slack table, ...) fills it straight into the grid instead of
  // dumping the raw separators into one cell: a pipe or comma starts the
  // next column, a new line starts the next row, anchored at whichever
  // cell you pasted into. A plain single value (no separators at all) is
  // left to the browser's own paste handling instead — replacing just the
  // one cell's text the normal way, cursor position and undo included.
  paste(event) {
    const text = event.clipboardData?.getData("text/plain")
    if (!text) return

    const rows = text.replace(/\r\n/g, "\n").split("\n").map((line) => line.split(/[,|]/).map((cell) => cell.trim()))
    // A trailing blank line is just how most apps terminate a copied
    // block, not a real empty row someone meant to paste.
    while (rows.length > 1 && rows[rows.length - 1].every((cell) => cell === "")) rows.pop()

    if (rows.length === 1 && rows[0].length === 1) return
    event.preventDefault()

    const startCell = event.target.closest("th, td")
    const startRow = startCell.closest("tr")
    const startRowIndex = Array.from(this.tableTarget.querySelectorAll("tr")).indexOf(startRow)
    const startColIndex = Array.from(startRow.children).indexOf(startCell)

    this.ensureColumnCount(startColIndex + Math.max(...rows.map((row) => row.length)))

    rows.forEach((values, rowOffset) => {
      this.ensureRowCount(startRowIndex + rowOffset + 1)
      const targetRow = this.tableTarget.querySelectorAll("tr")[startRowIndex + rowOffset]
      values.forEach((value, colOffset) => {
        const cell = targetRow.children[startColIndex + colOffset]
        if (cell) cell.textContent = value
      })
    })

    this.saveNow()
  }

  addRow() {
    this.insertRow()
    this.saveNow()
  }

  addColumn() {
    this.insertColumn()
    this.saveNow()
  }

  // Only ever removes from tbody — the header row (thead's own <tr>,
  // always present) isn't a "row" a person adds/removes, it's the table's
  // one required row. Removing every tbody row is exactly how you get a
  // "2x1" table: header only, no body.
  removeRow() {
    const body = this.tableTarget.querySelector("tbody")
    if (!body.lastElementChild) return

    body.lastElementChild.remove()
    this.saveNow()
  }

  // Guards at 1 rather than 0 — a table with zero columns has nothing left
  // to hold a row at all, so the minimum grid is 1 column.
  removeColumn() {
    const rows = this.tableTarget.querySelectorAll("tr")
    if (rows[0]?.children.length <= 1) return

    rows.forEach((row) => row.lastElementChild?.remove())
    this.saveNow()
  }

  // Grows the grid up to (at least) the given row/column count, used by
  // #paste to make room for pasted data that overflows the table's
  // current size — plain repeats of insertRow/insertColumn rather than
  // addRow/addColumn so a big paste triggers one save at the end, not one
  // per row/column added along the way.
  ensureRowCount(count) {
    while (this.tableTarget.querySelectorAll("tr").length < count) this.insertRow()
  }

  ensureColumnCount(count) {
    while ((this.tableTarget.querySelector("tr")?.children.length || 0) < count) this.insertColumn()
  }

  insertRow() {
    const table = this.tableTarget
    const columnCount = table.querySelector("tr")?.children.length || 1
    const row = document.createElement("tr")
    row.innerHTML = Array.from(
      { length: columnCount },
      () => `<td contenteditable="true" data-action="${CELL_ACTIONS}"> </td>`
    ).join("")
    table.querySelector("tbody").appendChild(row)
    return row
  }

  insertColumn() {
    const table = this.tableTarget
    table.querySelectorAll("tr").forEach((row, index) => {
      const cell = document.createElement(index === 0 ? "th" : "td")
      cell.contentEditable = "true"
      cell.textContent = " "
      cell.setAttribute("data-action", CELL_ACTIONS)
      row.appendChild(cell)
    })
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
