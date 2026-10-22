import { Controller } from "@hotwired/stimulus"

// Choosing a list's names from the catalog. The forms do the taking: a name is
// a button that posts itself, and Turbo redraws the box. This narrows the
// catalog by search and tags, hides what the box already holds, fills in Take
// all with what is showing, and lets a name be dragged into the box.
//
// Tags are picked the way Tom Select picks: typing in the tag box offers the
// tags that match, Enter or a click makes one a chip, and Backspace or its ×
// takes it off. What is typed and not picked is dropped on leaving the box, so
// the catalog always shows what Take all would take.
export default class extends Controller {
  static targets = [ "chosen", "dropzone", "search", "tagInput", "chipTemplate", "chip", "options", "option", "noTags",
                     "all", "empty", "control" ]

  connect() {
    this.controlTargets.forEach(control => control.hidden = false)
  }

  // On first sight, and every time the box is redrawn.
  chosenTargetConnected() {
    this.filter()
  }

  filter() {
    const chosen = new Set(this.chosenTarget.dataset.names.split(" "))
    const query = searched(this.searchTarget)
    const tags = this.picked
    const counts = {}
    const shown = []

    // A name shows when one of its characters carries every tag picked, and
    // counts toward only the tags those characters carry, once each.
    for (const { button, value, characters } of this.catalog) {
      const matching = characters.filter(carried => tags.every(tag => carried.includes(tag)))
      const hidden = chosen.has(value) || !value.includes(query) || matching.length == 0
      if (button.hidden != hidden) button.hidden = hidden
      if (hidden) continue

      shown.push(value)
      new Set(matching.flat()).forEach(tag => counts[tag] = (counts[tag] || 0) + 1)
    }

    // The box offers the tags the names showing carry, with how many carry
    // each, that match what is typed and are not picked already.
    const tagQuery = searched(this.tagInputTarget)
    for (const option of this.optionTargets) {
      const count = counts[option.dataset.tag] || 0
      option.lastElementChild.textContent = count
      option.hidden = count == 0 || tags.includes(option.dataset.tag) || !option.dataset.tag.includes(tagQuery)
    }
    this.noTagsTarget.hidden = this.offered.length > 0
    this.activate(this.best(tagQuery))

    this.allTarget.value = shown.join(" ")
    this.allTarget.textContent = `Take all ${shown.length}`
    this.allTarget.disabled = shown.length == 0
    this.emptyTarget.hidden = shown.length > 0
  }

  focusTags({ target }) {
    if (!target.closest("button")) this.tagInputTarget.focus()
  }

  openTags() {
    this.optionsTarget.hidden = false
    this.tagInputTarget.setAttribute("aria-expanded", true)
  }

  closeTags() {
    this.optionsTarget.hidden = true
    this.tagInputTarget.setAttribute("aria-expanded", false)
    if (this.tagInputTarget.value) {
      this.tagInputTarget.value = ""
      this.filter()
    }
  }

  searchTags() {
    this.openTags()
    this.filter()
  }

  tagKey(event) {
    const offered = this.offered
    switch (event.key) {
      case "ArrowDown":
      case "ArrowUp":
        event.preventDefault()
        this.openTags()
        if (offered.length == 0) break
        const step = event.key == "ArrowDown" ? 1 : -1
        this.activate(offered[(offered.indexOf(this.active) + step + offered.length) % offered.length])
        break
      case "Enter":
        if (this.optionsTarget.hidden || !this.active) break
        event.preventDefault()
        this.pick(this.active.dataset.tag)
        break
      case "Escape":
        this.closeTags()
        break
      case "Backspace":
        if (this.tagInputTarget.value || this.chipTargets.length == 0) break
        this.chipTargets.at(-1).remove()
        this.filter()
        break
    }
  }

  // Keeps the focus in the box, so it stays open for the click.
  hold(event) {
    event.preventDefault()
  }

  hover({ currentTarget }) {
    if (currentTarget != this.active) this.activate(currentTarget)
  }

  pickOption({ currentTarget }) {
    this.pick(currentTarget.dataset.tag)
  }

  pick(tag) {
    const chip = this.chipTemplateTarget.content.firstElementChild.cloneNode(true)
    chip.dataset.tag = tag
    chip.firstElementChild.textContent = tag
    this.tagInputTarget.before(chip)
    this.tagInputTarget.value = ""
    this.filter()
  }

  unpick({ currentTarget }) {
    currentTarget.closest("[data-tag]").remove()
    this.filter()
  }

  // The tag Enter would pick: highlighted in the list, and read out by a screen reader.
  activate(option) {
    this.active?.setAttribute("aria-selected", false)
    this.active = option
    if (option) {
      option.setAttribute("aria-selected", true)
      option.scrollIntoView({ block: "nearest" })
      this.tagInputTarget.setAttribute("aria-activedescendant", option.id)
    } else {
      this.tagInputTarget.removeAttribute("aria-activedescendant")
    }
  }

  // The tag named exactly, else the first starting with what is typed, else the first.
  best(query) {
    const offered = this.offered
    return offered.find(option => option.dataset.tag == query) ||
      offered.find(option => option.dataset.tag.startsWith(query)) || offered[0]
  }

  get picked() {
    return this.chipTargets.map(chip => chip.dataset.tag)
  }

  get offered() {
    return this.optionTargets.filter(option => !option.hidden)
  }

  drag({ target, dataTransfer }) {
    dataTransfer.setData(DRAGGED, target.value)
    dataTransfer.effectAllowed = "copy"
    this.dropzoneTarget.dataset.dragging = ""
  }

  dragged() {
    delete this.dropzoneTarget.dataset.dragging
  }

  over(event) {
    if (event.dataTransfer.types.includes(DRAGGED)) event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    const name = this.catalog.find(({ value }) => value == event.dataTransfer.getData(DRAGGED))
    name?.button.form.requestSubmit(name.button)
  }

  // A name of the list's own, typed in: clear the field once it is taken.
  added({ target, detail: { success } }) {
    if (success) target.reset()
  }

  // The catalog's names and each of their characters' tags, read from the page
  // once: they never change.
  get catalog() {
    return this.catalogNames ??= [ ...this.element.querySelectorAll("#catalog-names button") ].map(button =>
      ({ button, value: button.value, characters: button.dataset.tags.split("|").map(tags => tags.split(" ")) }))
  }
}

const DRAGGED = "application/x-wren-name"

// What a search field holds, written the way names and tags are.
function searched(field) {
  return field.value.trim().toLowerCase().replace(/\s+/g, "-")
}
