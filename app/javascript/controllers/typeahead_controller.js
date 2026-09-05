import { Controller } from "@hotwired/stimulus"

// Debounced typeahead search. Expects a JSON endpoint (SearchController)
// returning { results: [{ type, title, meta, url }] }.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String, minLength: { type: Number, default: 2 }, delay: { type: Number, default: 200 } }

  connect() {
    this.activeIndex = -1
    this.abortController = null
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    this.abortController?.abort()
  }

  search() {
    clearTimeout(this.debounceTimer)
    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.close()
      return
    }

    this.debounceTimer = setTimeout(() => this.fetchResults(query), this.delayValue)
  }

  async fetchResults(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal,
      })
      const data = await response.json()
      this.render(data.results || [])
    } catch (error) {
      if (error.name !== "AbortError") this.close()
    }
  }

  render(results) {
    this.activeIndex = -1

    if (results.length === 0) {
      this.resultsTarget.innerHTML = `<p class="search__empty">No results</p>`
    } else {
      this.resultsTarget.innerHTML = results
        .map(
          (result, index) => `
            <a class="search__result" href="${result.url}" data-index="${index}" data-action="mouseenter->typeahead#hover">
              <span class="search__result-title">${this.escape(result.title)}</span>
              <span class="search__result-meta">${this.escape(result.type)}${result.meta ? " · " + this.escape(result.meta) : ""}</span>
            </a>
          `
        )
        .join("")
    }

    this.open()
  }

  hover(event) {
    this.setActive(Number(event.currentTarget.dataset.index))
  }

  navigate(event) {
    const items = this.resultsTarget.querySelectorAll(".search__result")
    if (items.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.setActive(Math.min(this.activeIndex + 1, items.length - 1))
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.setActive(Math.max(this.activeIndex - 1, 0))
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      items[this.activeIndex].click()
    } else if (event.key === "Escape") {
      this.close()
    }
  }

  setActive(index) {
    const items = this.resultsTarget.querySelectorAll(".search__result")
    items.forEach((item) => item.classList.remove("is-active"))
    if (items[index]) {
      items[index].classList.add("is-active")
      this.activeIndex = index
    }
  }

  open() {
    this.resultsTarget.hidden = false
  }

  close() {
    this.resultsTarget.hidden = true
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
