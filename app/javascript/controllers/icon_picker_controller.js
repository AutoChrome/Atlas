import { Controller } from "@hotwired/stimulus"

// Font Awesome icon-name field on area/page forms: a filtered suggestion
// dropdown (positioned by our own CSS, unlike a native <datalist> — which
// can't be styled or positioned at all, that's a browser-chrome popup, not
// part of the page) plus a live preview of the chosen icon. Suggestions are
// fetched from IconSuggestionsController rather than embedded in the page —
// there are ~1,400 Font Awesome icon names, too many to ship on every
// area/page form load.
export default class extends Controller {
  static targets = ["input", "preview", "previewIcon", "results"]
  static values = { url: String }

  connect() {
    this.activeIndex = -1
    this.abortController = null
    this.updatePreview()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    this.abortController?.abort()
  }

  search() {
    this.updatePreview()
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.fetchSuggestions(), 150)
  }

  async fetchSuggestions() {
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const query = this.inputTarget.value.trim()
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal,
      })
      const data = await response.json()
      this.render(data.icons || [])
    } catch (error) {
      if (error.name !== "AbortError") this.close()
    }
  }

  render(matches) {
    this.activeIndex = -1

    if (matches.length === 0) {
      this.close()
      return
    }

    this.resultsTarget.innerHTML = matches
      .map(
        (name, index) => `
          <button type="button" class="search__result" data-index="${index}"
                  data-action="click->icon-picker#choose mouseenter->icon-picker#hover">
            <i class="fa-solid fa-${name} icon-fa"></i>
            <span class="search__result-title">${name}</span>
          </button>
        `
      )
      .join("")
    this.open()
  }

  choose(event) {
    this.inputTarget.value = event.currentTarget.querySelector(".search__result-title").textContent
    this.updatePreview()
    this.close()
  }

  hover(event) {
    this.setActive(Number(event.currentTarget.dataset.index))
  }

  navigate(event) {
    const items = this.resultsTarget.querySelectorAll(".search__result")
    if (items.length === 0 || this.resultsTarget.hidden) return

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

  updatePreview() {
    const name = this.inputTarget.value.trim().toLowerCase().replace(/[^a-z0-9-]/g, "")
    this.previewIconTarget.className = name ? `fa-solid fa-${name} icon-fa` : ""
    this.previewTarget.classList.toggle("icon-picker__preview--empty", !name)
  }
}
