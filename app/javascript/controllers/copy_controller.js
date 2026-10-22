import { Controller } from "@hotwired/stimulus"

// A Copy button for a piece of text: copies it, and says so for a moment.
// Where the clipboard is out of reach, as over plain HTTP, the text is
// selected instead, ready to copy by hand.
export default class extends Controller {
  static targets = [ "source", "label" ]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent)
      this.say("Copied")
    } catch {
      getSelection().selectAllChildren(this.sourceTarget)
      this.say("Selected")
    }
  }

  say(message) {
    this.original ??= this.labelTarget.textContent
    this.labelTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.labelTarget.textContent = this.original, 2000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
