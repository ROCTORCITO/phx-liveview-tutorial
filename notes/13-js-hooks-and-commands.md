# Lesson 13: JS Hooks & Commands

## Overview

LiveView minimizes JavaScript, but some things require client-side code: clipboard
access, canvas drawing, third-party JS libraries, browser APIs. JS Hooks and JS
Commands bridge this gap.

LiveView's server-rendered approach means the server controls the DOM. But some
browser APIs (clipboard, canvas, geolocation, Web Audio, etc.) require imperative
JavaScript that cannot be expressed as declarative HTML attributes. Hooks provide
that escape hatch.

**Source files:**
- `lib/liveview_lab_web/live/lesson13_js_hooks_live.ex`
- `assets/js/app.js` (hooks section)

---

## JS Commands (Phoenix.LiveView.JS)

JS Commands run **client-side** — no WebSocket roundtrip. They manipulate the DOM
directly.

**Important:** Some JS commands are purely client-side (toggle, show, hide,
add_class, etc.), while `JS.push` explicitly triggers a server roundtrip. The
power is in chaining both types together — instant visual feedback plus server
processing.

### Available Commands

```elixir
alias Phoenix.LiveView.JS

# Visibility
JS.toggle(to: "#element")              # Show/hide
JS.show(to: "#element")                # Show
JS.hide(to: "#element")                # Hide

# CSS Classes
JS.add_class("active", to: "#el")      # Add CSS class
JS.remove_class("active", to: "#el")   # Remove CSS class
JS.toggle_class("active", to: "#el")   # Toggle CSS class

# Attributes
JS.set_attribute({"disabled", ""}, to: "#el")
JS.remove_attribute("disabled", to: "#el")

# Transitions
JS.transition("fade-in", to: "#el")    # Run CSS transition

# Events & Navigation
JS.dispatch("my-event", to: "#el")     # Dispatch DOM event
JS.push("server-event")                # Push event to server (triggers roundtrip!)
JS.navigate("/path")                   # Navigate to a different LiveView (full mount)
JS.patch("/path")                      # Patch current LiveView (triggers handle_params)

# Focus
JS.focus(to: "#input")                 # Focus element
JS.focus_first(to: "#container")       # Focus first focusable child

# Execute another element's binding
JS.exec("phx-click", to: "#other")     # Triggers the JS command chain bound to
                                        # the phx-click attribute on #other
```

> **`JS.patch` vs `JS.navigate`:** `patch` stays within the current LiveView
> process and triggers `handle_params/3` — use it for filtering, sorting, or
> tab switching within the same view. `navigate` performs a live navigation to a
> (potentially different) LiveView, triggering a full mount cycle.

### Chaining Commands

Commands are chainable — they are dispatched sequentially on the client:

```elixir
JS.push("submit")
|> JS.hide(to: "#form")
|> JS.show(to: "#loading")
|> JS.transition("fade-in", to: "#loading")
```

> **Note on transitions:** `JS.transition` starts a CSS transition but does NOT
> block until it completes. The next command in the chain runs immediately. CSS
> transitions run asynchronously in the browser. Also, a subsequent server
> re-render may override DOM changes made by JS commands.

### Using in Templates

```heex
<button phx-click={JS.toggle(to: "#panel")}>Toggle Panel</button>
<button phx-click={JS.push("save") |> JS.hide(to: "#modal")}>Save & Close</button>

<%!-- Combine server event + client action --%>
<button phx-click={JS.push("delete") |> JS.transition("fade-out", to: "#row-1")}>
  Delete
</button>
```

### JS + Server Events

A common pattern: optimistic UI with JS Commands + server confirmation.

```heex
<button phx-click={
  JS.push("like")
  |> JS.add_class("text-red-500", to: "#heart")
  |> JS.transition("scale-125", to: "#heart")
}>
  <span id="heart">♥</span>
</button>
```

The heart immediately turns red (client-side), while the server processes the "like".
If the server action fails, the next re-render will reset the DOM to the correct state.

---

## JS Hooks

Hooks are JavaScript objects attached to DOM elements via `phx-hook="HookName"`.
They provide lifecycle callbacks and bidirectional communication.

### Defining Hooks

```javascript
// In assets/js/app.js
const Hooks = {}

Hooks.MyHook = {
  // Called when the element is first added to the DOM
  mounted() {
    console.log("Element mounted:", this.el)
  },

  // Called when the element is updated by LiveView's DOM patching.
  // More precisely: fires when the element is patched, which can happen
  // even if this element's own attributes didn't change (e.g., surrounding
  // DOM changed and LiveView re-patched the parent).
  updated() {
    console.log("Element updated")
  },

  // Called when the element is removed from the DOM
  destroyed() {
    console.log("Element destroyed")
  },

  // Called when the WebSocket disconnects
  disconnected() {
    console.log("Server disconnected")
  },

  // Called when the WebSocket reconnects
  reconnected() {
    console.log("Server reconnected")
  }
}

// Register hooks with LiveSocket
const liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  // ...
})
```

### Attaching Hooks

```heex
<div id="my-element" phx-hook="MyHook" data-config={Jason.encode!(@config)}>
  Content
</div>
```

`Jason.encode!/1` converts the Elixir map to a JSON string so it can be stored
in an HTML data attribute. The hook reads it via `this.el.dataset.config`.

**Rules:**
- Element **MUST** have a unique `id` — LiveView's DOM patching uses `id` to track
  elements. Without a stable `id`, LiveView can't tell if a hooked element was
  updated vs. replaced, causing `destroyed()` + `mounted()` instead of `updated()`.
- Only one hook per element (the `phx-hook` attribute accepts a single string).
  To compose multiple behaviors, combine them in one hook or use JS commands for
  the simpler ones.
- Access data attributes via `this.el.dataset`

### Hook API: `this`

Inside hook callbacks, `this` provides:

```javascript
this.el          // The DOM element
this.viewName    // The LiveView module name
this.pushEvent(event, payload, callback)  // Client → Server
this.pushEventTo(selector, event, payload, callback)
  // Targets a specific LiveView or LiveComponent. `selector` is a CSS
  // selector that matches an element with a `phx-target` attribute, or
  // the root element of a LiveView/LiveComponent.
this.handleEvent(event, callback)         // Listen for server → client
this.upload(name, files)                  // Trigger file upload
this.liveSocket                          // The LiveSocket instance
```

---

## Client → Server: pushEvent

```javascript
Hooks.SearchInput = {
  mounted() {
    let timeout
    this.el.addEventListener("input", (e) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => {
        this.pushEvent("search", { query: e.target.value })
      }, 300) // Debounce 300ms
    })
  }
}
```

```elixir
# Server
def handle_event("search", %{"query" => query}, socket) do
  results = search(query)
  {:noreply, assign(socket, results: results)}
end
```

### With Callbacks

```javascript
this.pushEvent("validate", { data: value }, (reply, ref) => {
  // reply = the map returned by the server's {:reply, map, socket}
  // ref = a unique reference for this event
  console.log("Server replied:", reply)
})
```

```elixir
# Server — note {:reply, ...} instead of the usual {:noreply, ...}
def handle_event("validate", params, socket) do
  {:reply, %{valid: true, errors: []}, socket}
end
```

---

## Server → Client: push_event + handleEvent

```elixir
# Server pushes event to client
def handle_event("trigger", _, socket) do
  {:noreply, push_event(socket, "highlight", %{color: "yellow", duration: 2000})}
end
```

```javascript
// Client hook receives it
Hooks.Highlighter = {
  mounted() {
    this.handleEvent("highlight", ({ color, duration }) => {
      this.el.style.backgroundColor = color
      setTimeout(() => {
        this.el.style.backgroundColor = ""
      }, duration)
    })
  }
}
```

---

## Common Hook Patterns

### Clipboard

```javascript
Hooks.Clipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      navigator.clipboard.writeText(this.el.dataset.text)
    })
  }
}
```

### Auto-resize Textarea

```javascript
Hooks.AutoResize = {
  mounted() {
    this.resize()
    this.el.addEventListener("input", () => this.resize())
  },
  updated() { this.resize() },
  resize() {
    this.el.style.height = "auto"
    this.el.style.height = this.el.scrollHeight + "px"
  }
}
```

### Chart.js Integration

```heex
<%!-- Server-side template --%>
<canvas id="my-chart" phx-hook="Chart" data-config={Jason.encode!(@chart_config)} />
```

```javascript
Hooks.Chart = {
  mounted() {
    this.chart = new Chart(this.el, JSON.parse(this.el.dataset.config))

    this.handleEvent("update_chart", ({ data }) => {
      this.chart.data = data
      this.chart.update()
    })
  },
  destroyed() {
    this.chart.destroy()
  }
}
```

### Scroll to Bottom (Chat)

```javascript
Hooks.ScrollBottom = {
  mounted() { this.scrollToBottom() },
  updated() { this.scrollToBottom() },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
```

### Keyboard Shortcuts

```javascript
Hooks.KeyHandler = {
  mounted() {
    // Note: attaching to `document` creates a global listener.
    // For simpler cases, consider LiveView's built-in `phx-window-keydown`
    // binding instead of a hook.
    this.handler = (e) => {
      if (e.ctrlKey && e.key === "Enter") {
        this.pushEvent("submit", {})
      }
      if (e.key === "Escape") {
        this.pushEvent("cancel", {})
      }
    }
    document.addEventListener("keydown", this.handler)
  },
  destroyed() {
    document.removeEventListener("keydown", this.handler)
  }
}
```

> **Built-in alternative:** For many keyboard shortcut cases, you can use
> `phx-window-keydown` and `phx-window-keyup` bindings directly in your template
> without needing a hook at all:
> ```heex
> <div phx-window-keydown="keypress" phx-key="Escape">...</div>
> ```

---

## LiveView 1.1: Colocated Hooks

LiveView 1.1 introduced **colocated hooks**, which let you define JavaScript hook
code directly within your component files. This keeps the hook next to the component
that uses it, improving maintainability.

### Syntax

```elixir
defmodule MyAppWeb.Components.Sortable do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <ul id="sortable-list" phx-hook=".Sortable">
      <li :for={item <- @items}>{item.name}</li>
    </ul>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Sortable">
      export default {
        mounted() {
          // Initialize sortable behavior
          this.el.addEventListener("dragend", (e) => {
            this.pushEvent("reorder", { order: this.getOrder() })
          })
        },
        getOrder() {
          return [...this.el.children].map(li => li.dataset.id)
        }
      }
    </script>
    """
  end
end
```

### Key points:
- The hook name is **dot-prefixed** (e.g., `.Sortable`) — this auto-namespaces
  it to the component module, avoiding name collisions
- The `<script>` tag uses `:type={Phoenix.LiveView.ColocatedHook}` and `name=".HookName"`
- The script must `export default` the hook object
- Colocated hooks are automatically collected and registered — no need to manually
  add them to `app.js`
- In `app.js`, colocated hooks are merged via `import { colocatedHooks } from "phoenix_live_view"`

---

## LiveView 1.1: phx-mounted & JS.ignore_attributes

### phx-mounted

Fires JS commands when an element is first mounted in the DOM:

```heex
<dialog id="my-dialog" phx-mounted={JS.exec("phx-click", to: "#open-btn")}>
  Dialog content
</dialog>
```

### JS.ignore_attributes

Prevents LiveView from patching specific attributes, useful for native HTML
elements where the browser controls an attribute:

```heex
<details phx-mounted={JS.ignore_attributes(["open"])}>
  <summary>Click to expand</summary>
  <p>Content that the browser shows/hides via the `open` attribute.</p>
</details>
```

Without `ignore_attributes`, LiveView's DOM patching would reset the `open`
attribute on every re-render, closing the `<details>` element.

---

## When to Use What

| Need | Use |
|---|---|
| Show/hide/toggle | `JS.toggle`, `JS.show`, `JS.hide` |
| CSS transitions | `JS.transition` |
| Optimistic UI | `JS.push` + `JS.add_class` chained |
| Browser APIs (clipboard, geolocation) | JS Hook |
| Third-party JS library | JS Hook |
| Complex client state | JS Hook |
| Debounce/throttle input | JS Hook (or `phx-debounce` for simple cases) |
| Canvas/WebGL | JS Hook |
| Server-initiated client action | `push_event` + `handleEvent` |
| Prevent attribute patching | `JS.ignore_attributes` + `phx-mounted` |
| Component-local JS behavior | Colocated hook (LiveView 1.1+) |

---

## Debugging

```javascript
// Enable LiveSocket debug logging — shows all events, diffs, and patches
// in the browser console
liveSocket.enableDebug()

// Simulate latency (test loading states) — adds delay to all roundtrips
liveSocket.enableLatencySim(2000) // 2 second delay

// In hooks — log element state on mount
mounted() {
  console.log("Hook mounted:", this.el.id, this.el.dataset)
}
```

---

## Exercises

1. Build a CodeMirror/Monaco editor hook that syncs content with the server
2. Implement drag-and-drop reordering with a JS hook + stream updates
3. Create a keyboard shortcut system (Ctrl+K for command palette)
4. Build a canvas drawing hook where strokes are broadcast via PubSub
5. Implement optimistic UI for a todo list (check/uncheck with JS, confirm on server)
