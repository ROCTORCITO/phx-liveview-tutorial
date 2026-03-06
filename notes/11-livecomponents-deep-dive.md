# Lesson 11: LiveComponents Deep Dive

## Overview

LiveView has two kinds of components: **function components** (stateless) and
**LiveComponents** (stateful). Knowing when to use which — and how they communicate
— is essential for building maintainable LiveView applications.

**Source files:**
- `lib/liveview_lab_web/live/lesson11_components_live.ex`
- `lib/liveview_lab_web/components/counter_component.ex`
- `lib/liveview_lab_web/components/editable_card_component.ex`

---

## Function Components vs LiveComponents

### Function Components (Stateless)

```elixir
# Definition
attr :name, :string, required: true
attr :class, :string, default: ""
slot :inner_block  # Reserved slot name for default content passed between tags

def greeting(assigns) do
  ~H"""
  <div class={@class}>
    Hello, {@name}!
    {render_slot(@inner_block)}
  </div>
  """
end

# Usage
<.greeting name="World" class="text-lg">
  <p>Welcome to LiveView</p>
</.greeting>
```

**Characteristics:**
- Just a function — no process, no state
- Re-renders when the parent re-renders AND the assigns passed to it have changed
  (LiveView's change tracking optimizes away unchanged components)
- Defined with `attr` and `slot` declarations
- Called with `<.component_name>` syntax (dot-prefix calls it as a local function)
- **Use by default** — covers 90% of cases

### LiveComponents (Stateful)

```elixir
defmodule MyApp.CounterComponent do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <span>{@count}</span>
      <button phx-click="inc" phx-target={@myself}>+</button>
    </div>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end
end

# Usage — note: <.live_component> calls Phoenix.Component.live_component/1
<.live_component module={MyApp.CounterComponent} id="my-counter" />
```

**Characteristics:**
- Has its own assigns map, logically isolated from the parent. **Important:**
  LiveComponents do NOT run in their own process — they share the parent LiveView's
  process. Their state is logically separate but managed within the same process.
- Has lifecycle callbacks (mount, update, render)
- Events target `@myself` to route to this component's `handle_event` (since
  multiple components share one process, `@myself` is a
  `%Phoenix.LiveComponent.CID{}` struct that uniquely identifies this instance)
- **Must have a unique `id` prop** — LiveView uses the `id` to track component
  instances across renders, route events to the right instance, and decide whether
  to call `mount/1` (new id) or just `update/2` (existing id)
- Can re-render independently via `send_update`, but also re-renders when the
  parent re-renders with changed props

---

## Lifecycle

```
First render:          Subsequent renders:
mount/1 → update/2 → render/1    update/2 → render/1
```

**Key distinction:** `mount/1` runs once (when the component first appears).
`update/2` runs on **every** render — both the first render and all subsequent
re-renders. This means `update/2` is the primary place to receive and apply props
from the parent.

### mount/1
Called once per component instance (first render only). Use it for one-time
initialization of internal state:

```elixir
def mount(socket) do
  {:ok, assign(socket, editing: false, count: 0)}
end
```

### update/2
Called on every render (including first). Receives props from parent.

```elixir
def update(assigns, socket) do
  # assigns = props passed from parent (includes :id)
  # socket.assigns = current component state

  socket =
    socket
    |> assign(:title, assigns.title)
    # assign_new only sets the value if the key does NOT already exist
    # in the socket. The function is only called when the key is absent.
    # This prevents parent re-renders from overwriting component-internal state.
    |> assign_new(:form, fn -> build_form(assigns) end)

  {:ok, socket}
end
```

**Important:** `update/2` receives ALL assigns from the parent each time.
Use `assign_new/3` to avoid overwriting component-internal state.

### render/1
Standard render function. Use `@myself` for event targeting.

---

## Communication Patterns

### Parent → Child: Props

```elixir
# Parent
<.live_component module={Card} id="card-1" title={@title} />
```

The child receives `title` in `update/2` on every parent re-render.

### Parent → Child: send_update

For imperative updates (e.g., "reset this component"):

```elixir
# Parent handle_event
def handle_event("reset", %{"id" => id}, socket) do
  send_update(CounterComponent, id: id, reset: true)
  {:noreply, socket}
end

# Child update/2 — pattern match to distinguish between regular props
# and imperative commands. Note: send_update always includes :id in
# the assigns map, even if your pattern match doesn't bind it.
def update(%{reset: true}, socket) do
  {:ok, assign(socket, count: 0)}
end

def update(assigns, socket) do
  {:ok, assign(socket, assigns)}
end
```

### Child → Parent: send/2

```elixir
# Child (in handle_event)
def handle_event("save", params, socket) do
  # self() in a LiveComponent returns the PARENT LiveView's PID,
  # because LiveComponents run inside the parent's process.
  send(self(), {:card_saved, socket.assigns.id, params})
  {:noreply, socket}
end

# Parent (handle_info) — the card_id tells which component sent the message
def handle_info({:card_saved, card_id, params}, socket) do
  # card_id identifies which card was saved, useful when you have
  # multiple instances of the same component
  {:noreply, put_flash(socket, :info, "Card #{card_id} saved!")}
end
```

### Child → Parent: Events Bubbling

Events without `phx-target` bubble up to the parent LiveView:

```heex
<%!-- In child template, NO phx-target --%>
<button phx-click="delete" phx-value-id={@id}>Delete</button>
```

The parent's `handle_event("delete", ...)` will be called.

---

## Slots

### Basic Slots

```elixir
# inner_block is the reserved name for default slot content
slot :inner_block, required: true

def card(assigns) do
  ~H"""
  <div class="card">
    {render_slot(@inner_block)}
  </div>
  """
end
```

### Named Slots

```elixir
slot :header, required: true
slot :footer

def card(assigns) do
  ~H"""
  <div class="card">
    <header>{render_slot(@header)}</header>
    <main>{render_slot(@inner_block)}</main>
    <footer :if={@footer != []}>{render_slot(@footer)}</footer>
  </div>
  """
end

# Usage
<.card>
  <:header>Title</:header>
  Body content
  <:footer>Footer</:footer>
</.card>
```

### Slots with Arguments

```elixir
slot :col, required: true do
  attr :label, :string, required: true
end

def table(assigns) do
  ~H"""
  <table>
    <thead>
      <tr>
        <th :for={col <- @col}>{col.label}</th>
      </tr>
    </thead>
    <tbody>
      <tr :for={row <- @rows}>
        <td :for={col <- @col}>
          {render_slot(col, row)}
        </td>
      </tr>
    </tbody>
  </table>
  """
end

# Usage
<.table rows={@users}>
  <:col :let={user} label="Name">{user.name}</:col>
  <:col :let={user} label="Email">{user.email}</:col>
</.table>
```

---

## When to Use LiveComponent

Use a **LiveComponent** when you need:
1. **Isolated state** — component tracks its own state (e.g., open/closed, form data)
   that shouldn't be in the parent's assigns
2. **Component-scoped events** — events handled within the component via `@myself`
3. **Form isolation** — component manages its own form/changeset independently
4. **Targeted re-renders** — update just this component via `send_update` without
   re-rendering the entire parent (matters for performance when the parent template
   is expensive to diff)

Use a **function component** for everything else:
- Display-only UI (cards, badges, layouts)
- Reusable markup patterns
- Slot-based composition

**Rule of thumb:** Start with function components. Only "upgrade" to LiveComponent
when you hit a wall.

---

## Anti-Patterns

### 1. LiveComponent for pure display
```elixir
# BAD: No state needed, just use a function component
defmodule Badge do
  use Phoenix.LiveComponent
  def render(assigns), do: ~H"<span class='badge'>{@text}</span>"
end

# GOOD: Function component — define in any module that `use Phoenix.Component`
# (your CoreComponents module, or the Layouts module, etc.)
def badge(assigns), do: ~H"<span class='badge'>{@text}</span>"
```

### 2. Passing too many props
```elixir
# BAD: Component knows about everything
<.live_component module={UserCard}
  id={user.id} user={user} permissions={@perms}
  current_user={@current_user} theme={@theme} />

# GOOD: Pass only what's needed
<.live_component module={UserCard}
  id={user.id} user={user} can_edit?={can_edit?(user, @current_user)} />
```

### 3. Deep component nesting
LiveComponents add overhead from the additional lifecycle callbacks (mount/update)
and internal state tracking. Don't nest them 5 levels deep. Flatten when possible.

---

## Exercises

1. Convert the CounterComponent to emit events to the parent (track total clicks)
2. Build a TabsComponent with named slots for each tab panel
3. Create a Modal LiveComponent with open/close state and `send_update` trigger
4. Implement an Accordion component using only function components + JS commands
