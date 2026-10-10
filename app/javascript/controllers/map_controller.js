import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

// Draws one circle per tower, sized by the number of calls that used it.
//
// The server works out what to show and passes it in as data-map-towers-value;
// this controller only draws. When the filter form replaces the Turbo Frame,
// the old element is removed (disconnect) and the new one is drawn (connect).
export default class extends Controller {
  static values = { towers: Array }

  connect() {
    this.map = L.map(this.element)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(this.map)

    const busiest = Math.max(...this.towersValue.map((tower) => tower.calls))
    const circles = this.towersValue.map((tower) =>
      // Square root so a circle's area, not its radius, tracks the call count.
      L.circleMarker([ tower.lat, tower.lng ], { radius: 8 + 14 * Math.sqrt(tower.calls / busiest) })
        .bindPopup(this.popup(tower))
    )

    const group = L.featureGroup(circles).addTo(this.map)
    this.map.fitBounds(group.getBounds().pad(0.3), { maxZoom: 14 })
  }

  disconnect() {
    this.map.remove()
  }

  // Built from DOM nodes with textContent rather than an HTML string: tower
  // codes come from uploaded files and must never be interpreted as markup.
  popup(tower) {
    const lines = [
      tower.code,
      `${tower.calls} ${tower.calls === 1 ? "call" : "calls"}`,
      tower.calls === 1 ? tower.first : `${tower.first} to ${tower.last} UTC`
    ]

    const box = document.createElement("div")
    lines.forEach((text, index) => {
      const line = document.createElement(index === 0 ? "strong" : "div")
      line.textContent = text
      box.append(line)
    })
    return box
  }
}
