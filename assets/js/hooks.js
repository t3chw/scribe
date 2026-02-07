let Hooks = {}

Hooks.Clipboard = {
    mounted() {
        this.handleEvent("copy-to-clipboard", ({ text: text }) => {
            navigator.clipboard.writeText(text).then(() => {
                this.pushEventTo(this.el, "copied-to-clipboard", { text: text })
                setTimeout(() => {
                    this.pushEventTo(this.el, "reset-copied", {})
                }, 2000)
            })
        })
    }
}

Hooks.ChatScroll = {
    mounted() {
        this.scrollToBottom()
    },
    updated() {
        this.scrollToBottom()
    },
    scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight
    }
}

Hooks.ChatInput = {
    mounted() {
        this.mentionActive = false
        this.mentionStart = -1
        this.selectedIndex = -1
        this.savedValue = ""
        this.savedCursor = 0

        this.el.addEventListener("keydown", (e) => {
            if (this.mentionActive) {
                const suggestions = document.getElementById("mention-suggestions")
                const items = suggestions ? suggestions.querySelectorAll("button") : []

                if (e.key === "ArrowDown") {
                    e.preventDefault()
                    this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
                    this._highlightItem(items)
                    return
                }
                if (e.key === "ArrowUp") {
                    e.preventDefault()
                    this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
                    this._highlightItem(items)
                    return
                }
                if (e.key === "Tab") {
                    e.preventDefault()
                    const idx = this.selectedIndex >= 0 ? this.selectedIndex : 0
                    if (items[idx]) {
                        items[idx].click()
                    }
                    return
                }
                if (e.key === "Enter") {
                    e.preventDefault()
                    if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
                        items[this.selectedIndex].click()
                    }
                    return
                }
                if (e.key === "Escape") {
                    e.preventDefault()
                    this.mentionActive = false
                    this.mentionStart = -1
                    this.selectedIndex = -1
                    this.pushEventTo(this.el, "clear_mentions", {})
                    return
                }
            }

            if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                const form = this.el.closest("form")
                if (form) {
                    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
                }
            }
        })

        this.el.addEventListener("input", (e) => {
            const val = this.el.value
            const cursor = this.el.selectionStart

            // Find the last @ before the cursor
            let atIdx = -1
            for (let i = cursor - 1; i >= 0; i--) {
                if (val[i] === "@") {
                    atIdx = i
                    break
                }
                // Stop if we hit a space before finding text (except spaces within a name)
                if (val[i] === "\n") break
            }

            if (atIdx >= 0) {
                const query = val.substring(atIdx + 1, cursor)
                // Only activate if query has no newlines and is reasonable length
                if (query.length >= 1 && query.length <= 50 && !query.includes("\n")) {
                    this.mentionActive = true
                    this.mentionStart = atIdx
                    this.selectedIndex = -1
                    this.savedValue = val
                    this.savedCursor = cursor
                    this.pushEventTo(this.el, "search_mentions", { query: query })
                    return
                }
            }

            if (this.mentionActive) {
                this.mentionActive = false
                this.mentionStart = -1
                this.selectedIndex = -1
                this.pushEventTo(this.el, "clear_mentions", {})
            }
        })

        this.handleEvent("mention_selected", ({ name }) => {
            const val = this.savedValue || this.el.value
            const before = val.substring(0, this.mentionStart)
            const after = val.substring(this.savedCursor)
            const newVal = before + "@" + name + " " + after
            this.el.value = newVal

            const newCursor = before.length + name.length + 2 // @name + space
            this.el.selectionStart = newCursor
            this.el.selectionEnd = newCursor
            this.el.focus()

            this.mentionActive = false
            this.mentionStart = -1
            this.selectedIndex = -1
        })
    },

    _highlightItem(items) {
        items.forEach((item, i) => {
            if (i === this.selectedIndex) {
                item.classList.add("bg-slate-100")
            } else {
                item.classList.remove("bg-slate-100")
            }
        })
    }
}

export default Hooks