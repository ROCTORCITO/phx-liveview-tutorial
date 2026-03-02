# Lesson 4: Events & Bindings

## Overview

LiveView's event system is what makes server-rendered HTML feel like a single-page
application. Every user interaction — clicks, keystrokes, form inputs — travels over
the WebSocket to the server, where `handle_event/3` processes it and returns new
assigns. LiveView then diffs the new template against the old one and sends only the
changed fragments back to the browser.

Understanding the full event flow and the available bindings is essential for building
responsive LiveView applications without reaching for custom JavaScript.

**Source file:** `lib/liveview_lab_web/live/lesson4_events_live.ex`

---

## Core Concepts

### 1. Event Flow

Every LiveView event follows the same lifecycle:

```
User action (click, keypress, input)
  → phx-* binding fires
    → Event sent over WebSocket as JSON
      → handle_event/3 called on the server
        → Returns {:noreply, updated_socket} with new assigns
          → LiveView diffs the template
            → Only changed fragments sent to client
              → Client patches the DOM
```

This means every event is a server round-trip. The latency is typically 1-10ms on
local networks and 20-100ms over the internet. LiveView's diff engine ensures that
only the minimal payload is sent back, keeping the round-trip fast.

---

### 2. Click Events

The most common binding. Fires when the user clicks an element.

```heex
<%!-- Basic click event --%>
<button phx-click="increment">+1</button>

<%!-- Click with a value --%>
<button phx-click="delete" phx-value-id={item.id}>Delete</button>
```

```elixir
def handle_event("increment", _params, socket) do
  {:noreply, assign(socket, count: socket.assigns.count + 1)}
end

def handle_event("delete", %{"id" => id}, socket) do
  # Note: id is ALWAYS a string, even if you passed an integer
  item_id = String.to_integer(id)
  {:noreply, assign(socket, items: Enum.reject(socket.assigns.items, &(&1.id == item_id)))}
end
```

**Click with JS commands:** You can combine server events with client-side JS
commands for instant feedback:

```heex
<button phx-click={JS.push("delete", value: %{id: item.id}) |> JS.hide(to: "#item-#{item.id}")}>
  Delete
</button>
```

This hides the element immediately on the client while the server processes the
delete. If the server event fails, the element reappears on the next render.

---

### 3. Form Events

Forms use two primary bindings: `phx-change` for live validation and `phx-submit`
for final submission.

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} label="Name" />
  <.input field={@form[:email]} label="Email" />
  <button type="submit">Save</button>
</.form>
```

```elixir
# phx-change fires on EVERY input change (each keystroke, each select, each toggle)
def handle_event("validate", %{"user" => user_params}, socket) do
  changeset =
    %User{}
    |> User.changeset(user_params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, form: to_form(changeset))}
end

# phx-submit fires when the form is submitted (Enter key or submit button)
def handle_event("save", %{"user" => user_params}, socket) do
  case Accounts.create_user(user_params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "User created!")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

**`phx-change` vs `phx-submit`:**

| Aspect | `phx-change` | `phx-submit` |
|---|---|---|
| When it fires | Every input change | Form submission |
| Use for | Live validation, search-as-you-type | Saving data |
| Frequency | High (every keystroke) | Once per submission |
| Typical handler | Validate changeset, update form | Persist to database |

---

### 4. Focus Events

Fire when elements gain or lose focus.

```heex
<input
  phx-focus="field_focused"
  phx-blur="field_blurred"
  phx-value-field="email"
/>
```

```elixir
def handle_event("field_focused", %{"field" => field}, socket) do
  {:noreply, assign(socket, focused_field: field)}
end

def handle_event("field_blurred", %{"field" => field}, socket) do
  {:noreply, assign(socket, focused_field: nil)}
end
```

Focus events are useful for showing contextual help, triggering validation on blur,
or tracking which field the user is editing in collaborative scenarios.

---

### 5. Key Events

Capture keyboard events on specific elements or globally.

```heex
<%!-- Key events on a specific element (element must be focusable) --%>
<div phx-keydown="key_pressed" phx-key="Enter">
  Press Enter here
</div>

<%!-- Key events on any key --%>
<input phx-keydown="search_keydown" phx-keyup="search_keyup" />

<%!-- Global key events (window-level, fires regardless of focus) --%>
<div phx-window-keydown="global_keydown">
  <%!-- This captures ALL keydown events on the page --%>
</div>
```

```elixir
# phx-key filters to a specific key — only "Enter" triggers this
def handle_event("key_pressed", _params, socket) do
  {:noreply, assign(socket, submitted: true)}
end

# Without phx-key, ALL keys trigger the event. The key is in params.
def handle_event("search_keydown", %{"key" => key} = _params, socket) do
  case key do
    "Escape" -> {:noreply, assign(socket, query: "", results: [])}
    "ArrowDown" -> {:noreply, assign(socket, selected_index: socket.assigns.selected_index + 1)}
    _ -> {:noreply, socket}
  end
end

# Global keydown — useful for keyboard shortcuts
def handle_event("global_keydown", %{"key" => "k", "metaKey" => true}, socket) do
  # Cmd+K to open command palette
  {:noreply, assign(socket, show_command_palette: true)}
end

def handle_event("global_keydown", _params, socket) do
  {:noreply, socket}
end
```

**Available key event bindings:**

| Binding | Scope | Use case |
|---|---|---|
| `phx-keydown` | Focused element | Input handling |
| `phx-keyup` | Focused element | Key release detection |
| `phx-window-keydown` | Entire window | Global shortcuts |
| `phx-window-keyup` | Entire window | Global key release |
| `phx-key="Enter"` | Filter modifier | Restrict to one key |

---

### 6. Value Bindings

Pass data from the template to the server with `phx-value-*` attributes.

```heex
<button
  phx-click="select_item"
  phx-value-id="42"
  phx-value-name="Widget"
  phx-value-category="tools"
>
  Select Widget
</button>
```

```elixir
def handle_event("select_item", params, socket) do
  # params = %{"id" => "42", "name" => "Widget", "category" => "tools"}
  #
  # IMPORTANT: ALL values are strings, even if you wrote phx-value-id={42}
  # The integer 42 becomes the string "42" by the time it reaches handle_event.
  id = String.to_integer(params["id"])
  name = params["name"]

  {:noreply, assign(socket, selected: %{id: id, name: name})}
end
```

**Naming convention:** `phx-value-some-thing` becomes `params["some-thing"]`. The
attribute name after `phx-value-` is used as-is (hyphens are preserved, no
conversion to underscores).

---

### 7. Debounce & Throttle

Control how frequently events fire. Critical for performance on high-frequency
events like typing or scrolling.

```heex
<%!-- Debounce: waits until the user STOPS typing for 300ms, then fires --%>
<input phx-change="search" phx-debounce="300" />

<%!-- Throttle: fires at most once every 300ms, even if the user keeps typing --%>
<input phx-change="track_input" phx-throttle="300" />

<%!-- Debounce on blur: fires only when the input loses focus --%>
<input phx-change="validate_field" phx-debounce="blur" />
```

**Debounce vs Throttle:**

```
User typing: a...b...c...d...[stops]
                                    ↓
Debounce 300ms:                     ✓ fires once (300ms after last input)

User typing: a...b...c...d...[stops]
             ↓           ↓          ↓
Throttle 300ms: ✓ fires  ✓ fires   ✓ fires (at 300ms intervals)
```

| Modifier | Behavior | Best for |
|---|---|---|
| `phx-debounce="300"` | Waits until idle for 300ms | Search-as-you-type, validation |
| `phx-throttle="300"` | Fires at most every 300ms | Scroll tracking, drag events |
| `phx-debounce="blur"` | Fires when input loses focus | Field-level validation on tab-out |

---

### 8. Loading States

LiveView automatically adds CSS classes to elements during the server round-trip,
giving you visual feedback without any JavaScript.

```heex
<button phx-click="save">
  Save
</button>

<style>
  /* These classes are added automatically during the round-trip */
  [phx-click-loading] {
    opacity: 0.5;
    pointer-events: none;
  }
</style>
```

**Automatic loading classes:**

| Class | Added when... |
|---|---|
| `phx-click-loading` | A `phx-click` event is in-flight |
| `phx-submit-loading` | A `phx-submit` event is in-flight |
| `phx-change-loading` | A `phx-change` event is in-flight |

These classes are added to the element that triggered the event and are removed
when the server responds.

```heex
<%!-- Common pattern: disable button and show spinner during submission --%>
<button phx-click="process" class="btn">
  <span class="phx-click-loading:hidden">Process</span>
  <span class="hidden phx-click-loading:inline">Processing...</span>
</button>

<%!-- Form-level loading --%>
<.form for={@form} phx-submit="save">
  <%!-- inputs... --%>
  <button type="submit" phx-disable-with="Saving...">
    Save
  </button>
</.form>
```

`phx-disable-with` is a convenience attribute that replaces the button text and
disables the button during form submission.

---

## Common Pitfalls

1. **All `phx-value-*` params are strings** — `phx-value-id={42}` arrives as
   `%{"id" => "42"}`, not `%{"id" => 42}`. Always convert with
   `String.to_integer/1` or pattern-match on the string.

2. **Not handling empty form fields** — Unchecked checkboxes and empty selects may
   not appear in the params at all. Use `Map.get(params, "field", default)` instead
   of `params["field"]` when a default is needed.

3. **Debounce vs throttle confusion** — Debounce waits until activity stops (good
   for search). Throttle fires at a steady rate (good for scroll/drag). Using
   throttle for search means partial queries hit the server. Using debounce for
   scroll tracking means you miss intermediate positions.

4. **Forgetting that events are server round-trips** — Every `phx-click`,
   `phx-change`, etc. goes to the server and back. On high-latency connections this
   can feel sluggish. Use JS commands (`JS.toggle`, `JS.show`, `JS.hide`) for
   purely visual changes that don't need server state.

5. **Global key events firing too often** — `phx-window-keydown` fires for every
   keystroke on the page. Always have a catch-all clause that returns `{:noreply,
   socket}` for keys you don't care about.

6. **Not debouncing `phx-change` on forms** — Without debounce, every keystroke
   sends a server event. For forms with many fields, add `phx-debounce="300"` to
   text inputs or use `phx-debounce="blur"` for less frequent validation.

---

## Exercises

1. Build a counter with `phx-click` that increments and decrements, passing the
   direction via `phx-value-direction="up"` or `"down"`
2. Create a search input with `phx-change` and `phx-debounce="300"` that filters a
   list of items
3. Implement a form with live validation (`phx-change="validate"`) that shows
   inline errors, and a `phx-submit="save"` handler
4. Add keyboard shortcuts using `phx-window-keydown`: Escape to close a modal,
   `/` to focus the search input
5. Build a button with `phx-disable-with` that simulates a slow operation (use
   `Process.sleep(2000)` in the handler) and observe the loading state
