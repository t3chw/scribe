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
        this.mirror = document.getElementById("chat-input-mirror")

        this._syncMirror()

        this.el.addEventListener("keydown", (e) => {
            // Mention dropdown navigation
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

            // Backspace: delete whole @mention tag if cursor is right after one
            if (e.key === "Backspace") {
                const cursor = this.el.selectionStart
                const selEnd = this.el.selectionEnd
                // Only handle when there's no text selection (just a cursor)
                if (cursor === selEnd && cursor > 0) {
                    const val = this.el.value
                    const before = val.substring(0, cursor)
                    // Check if cursor is right after a mention: @Name or @First Last
                    // Optionally with a trailing space
                    const mentionMatch = before.match(/@[A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?\s?$/)
                    if (mentionMatch) {
                        e.preventDefault()
                        const mentionStartIdx = cursor - mentionMatch[0].length
                        const after = val.substring(cursor)
                        this.el.value = val.substring(0, mentionStartIdx) + after
                        this.el.selectionStart = mentionStartIdx
                        this.el.selectionEnd = mentionStartIdx
                        this._syncMirror()
                        return
                    }
                }
            }

            // Enter to send message
            if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                const form = this.el.closest("form")
                if (form) {
                    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
                }
                // Clear textarea and mirror after sending
                setTimeout(() => {
                    this.el.value = ""
                    this._syncMirror()
                }, 0)
            }
        })

        this.el.addEventListener("input", (e) => {
            const val = this.el.value
            const cursor = this.el.selectionStart

            this._syncMirror()

            // Find the last @ before the cursor
            let atIdx = -1
            for (let i = cursor - 1; i >= 0; i--) {
                if (val[i] === "@") {
                    atIdx = i
                    break
                }
                if (val[i] === "\n") break
            }

            if (atIdx >= 0) {
                const query = val.substring(atIdx + 1, cursor)
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

            const newCursor = before.length + name.length + 2
            this.el.selectionStart = newCursor
            this.el.selectionEnd = newCursor
            this.el.focus()

            this.mentionActive = false
            this.mentionStart = -1
            this.selectedIndex = -1

            this._syncMirror()
        })

        // Sync scroll between textarea and mirror
        this.el.addEventListener("scroll", () => {
            if (this.mirror) {
                this.mirror.scrollTop = this.el.scrollTop
            }
        })
    },

    _syncMirror() {
        if (!this.mirror) return
        const val = this.el.value
        if (!val) {
            this.mirror.innerHTML = ""
            return
        }
        this.mirror.innerHTML = this._buildMirrorHtml(val)
    },

    _buildMirrorHtml(text) {
        const mentionRegex = /@[A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?/g
        let result = ""
        let lastIndex = 0
        let match

        while ((match = mentionRegex.exec(text)) !== null) {
            const before = text.substring(lastIndex, match.index)
            result += this._escapeHtml(before)

            // Keep exact same text (including @) — just add background highlight
            result += '<span class="bg-slate-200 rounded">' +
                this._escapeHtml(match[0]) + '</span>'

            lastIndex = match.index + match[0].length
        }

        result += this._escapeHtml(text.substring(lastIndex))

        if (text.endsWith("\n")) {
            result += "<br>"
        }

        return result
    },

    _escapeHtml(text) {
        return text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\n/g, "<br>")
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
