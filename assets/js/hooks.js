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
        this.handleEvent("chat_scroll_bottom", () => {
            requestAnimationFrame(() => this.scrollToBottom())
        })
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
            // Mention dropdown navigation — only when dropdown is actually visible
            const suggestions = document.getElementById("mention-suggestions")
            const items = suggestions ? suggestions.querySelectorAll("button") : []
            const dropdownVisible = this.mentionActive && items.length > 0

            if (dropdownVisible) {
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
                if (cursor === selEnd && cursor > 0) {
                    const val = this.el.value
                    const before = val.substring(0, cursor)
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
                const message = this.el.value.trim()
                if (message === "") return

                // Clear immediately before submitting
                this.el.value = ""
                this._syncMirror()
                this.mentionActive = false
                this.mentionStart = -1
                this.selectedIndex = -1

                // Push the message directly to the server
                this.pushEventTo(this.el, "send_message", { message: message })
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

        // Clear textarea when form is submitted via button click
        const form = this.el.closest("form")
        if (form) {
            form.addEventListener("submit", () => {
                setTimeout(() => {
                    this.el.value = ""
                    this._syncMirror()
                }, 0)
            })
        }

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

Hooks.LocalTime = {
    mounted() {
        this._formatTime()
    },
    updated() {
        this._formatTime()
    },
    _formatTime() {
        const utc = this.el.dataset.utc
        if (!utc) return
        const date = new Date(utc)
        const h = date.getHours()
        const m = date.getMinutes().toString().padStart(2, "0")
        const ampm = h >= 12 ? "pm" : "am"
        const h12 = h % 12 || 12
        const months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
        const format = this.el.dataset.format

        if (format === "date-time") {
            this.el.textContent = `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()} at ${h12}:${m} ${ampm.toUpperCase()}`
        } else {
            this.el.textContent = `${h12}:${m}${ampm} - ${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`
        }
    }
}

export default Hooks
