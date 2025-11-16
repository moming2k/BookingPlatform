import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle(event) {
    event.preventDefault()
    const menu = document.querySelector('[data-mobile-menu-target="menu"]')
    if (menu) {
      menu.classList.toggle("hidden")
    }
  }
}
