import { Controller } from "@hotwired/stimulus"

// Adds a custom "link to a page/area" button to the Trix toolbar, so
// content can reference other Areas/Pages without copy-pasting URLs.
// Reuses the existing sidebar search endpoint (SearchController) rather
// than a separate one.
export default class extends Controller {
  static targets = ["editor", "dialog", "input", "results"]
  static values = { searchUrl: String }

  connect() {
    this.trixElement = this.editorTarget
    if (this.trixElement.editor) {
      this.injectButton()
    } else {
      this.trixElement.addEventListener("trix-initialize", () => this.injectButton(), { once: true })
    }
  }

  injectButton() {
    const toolbar = this.trixElement.toolbarElement
    if (!toolbar || toolbar.querySelector(".page-reference-button")) return

    const group = document.createElement("span")
    group.className = "trix-button-group"
    group.innerHTML = `
      <button type="button" class="trix-button page-reference-button" title="Link to a page or area" tabindex="-1">
        <i class="fa-solid fa-link icon-fa"></i>
      </button>
    `
    toolbar.querySelector(".trix-button-row").appendChild(group)
    group.querySelector("button").addEventListener("click", (event) => {
      event.preventDefault()
      this.open()
    })
  }

  open() {
    // Trix loses its DOM selection once focus moves to the dialog, so the
    // range has to be captured now and restored right before inserting.
    this.savedRange = this.trixElement.editor.getSelectedRange()
    this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
    this.dialogTarget.showModal()
    this.inputTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  async search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.fetchResults(), 150)
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    try {
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
      })
      const data = await response.json()
      this.render(data.results || [])
    } catch (error) {
      this.resultsTarget.innerHTML = `<p class="search__empty">Search unavailable</p>`
    }
  }

  render(results) {
    if (results.length === 0) {
      this.resultsTarget.innerHTML = `<p class="search__empty">No results</p>`
      return
    }

    this.resultsTarget.innerHTML = results
      .map(
        (result) => `
          <button type="button" class="search__result" data-action="page-reference#insert"
                  data-url="${this.escape(result.url)}" data-title="${this.escape(result.title)}">
            <span class="search__result-title">${this.escape(result.title)}</span>
            <span class="search__result-meta">${this.escape(result.type)}${result.meta ? " · " + this.escape(result.meta) : ""}</span>
          </button>
        `
      )
      .join("")
  }

  insert(event) {
    const { url, title } = event.currentTarget.dataset
    const editor = this.trixElement.editor

    if (this.savedRange) editor.setSelectedRange(this.savedRange)
    editor.insertHTML(`<a href="${url}">${this.escape(title)}</a>`)

    this.close()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
