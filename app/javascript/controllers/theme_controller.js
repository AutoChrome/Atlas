import { Controller } from "@hotwired/stimulus"

// Toggles data-theme="light"|"dark" on <html>, persisted in localStorage.
// With no stored preference, the theme CSS (themes/_dark.scss) already
// falls back to prefers-color-scheme, so this controller only needs to act
// once the viewer makes an explicit choice. Which icon is visible is handled
// entirely by CSS reacting to data-theme (see components/_icons.scss).
export default class extends Controller {
  connect() {
    this.apply(this.stored || this.systemPreference)
  }

  toggle() {
    this.apply(this.current === "dark" ? "light" : "dark")
  }

  apply(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    try {
      localStorage.setItem("theme", theme)
    } catch (e) {
      // Storage unavailable (private browsing, etc) — theme just won't persist.
    }
  }

  get current() {
    return document.documentElement.getAttribute("data-theme")
  }

  get stored() {
    try {
      return localStorage.getItem("theme")
    } catch (e) {
      return null
    }
  }

  get systemPreference() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}
