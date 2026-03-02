# Lesson 6: Function Components

## Overview

Function components are the primary building block for reusable UI in Phoenix
LiveView. They are pure render functions: no process, no state, no lifecycle. They
take assigns as input and return HEEx markup as output. Understanding how to define,
compose, and organize function components — including attributes, slots, and global
attributes — is essential for building maintainable LiveView applications.

Most of the UI in a LiveView app should be function components. LiveComponents
(stateful) are the exception, not the rule.

**Source file:** `lib/liveview_lab_web/live/lesson6_function_components_live.ex`

---

## Core Concepts

### 1. What Function Components Are

A function component is a regular Elixir function that:
- Takes a single `assigns` argument (a map)
- Returns a HEEx template via `~H`
- Has **no process** — it runs inside the caller's process
- Has **no state** — it renders based entirely on the assigns it receives
- Has **no lifecycle** — no `mount`, no `update`, no `handle_event`

When LiveView re-renders, it calls your function component again with the new
assigns. LiveView's change tracking ensures the function is only called when its
assigns have actually changed.

---

### 2. Defining Function Components

```elixir
# Basic function component
# The dot-prefix in <.greeting> calls this as a local function
attr :name, :string, required: true

def greeting(assigns) do
  ~H"""
  <p>Hello, {@name}!</p>
  """
end
```

```heex
<%!-- Usage --%>
<.greeting name="World" />
<.greeting name={@current_user.name} />
```

**The dot-prefix convention:**
- `<.greeting>` — calls a function in the current module (or imported)
- `<MyAppWeb.CoreComponents.button>` — calls a function in another module (fully
  qualified)
- `<button>` — plain HTML element (no dot, no module path)

```elixir
# Private helper components (defp) are scoped to the current module
# — useful for components only used within one LiveView
defp status_badge(assigns) do
  ~H"""
  <span class={["badge", badge_class(@status)]}>
    {@status}
  </span>
  """
end

defp badge_class(:active), do: "badge-green"
defp badge_class(:inactive), do: "badge-gray"
defp badge_class(:error), do: "badge-red"
```

---

### 3. Attributes

Attributes are the props of function components. They provide compile-time
validation, documentation, and default values.

```elixir
attr :name, :string, required: true
attr :count, :integer, default: 0
attr :variant, :string, values: ~w(primary secondary danger)
attr :disabled, :boolean, default: false
attr :on_click, JS, default: %JS{}
attr :items, :list, default: []
attr :metadata, :map, default: %{}
attr :class, :string, default: nil

def button(assigns) do
  ~H"""
  <button
    class={["btn", "btn-#{@variant}", @class]}
    disabled={@disabled}
    phx-click={@on_click}
  >
    {render_slot(@inner_block)}
  </button>
  """
end
```

**Available attribute types:**

| Type | Elixir type | Example |
|---|---|---|
| `:string` | binary | `"hello"` |
| `:integer` | integer | `42` |
| `:float` | float | `3.14` |
| `:boolean` | boolean | `true` / `false` |
| `:atom` | atom | `:primary` |
| `:list` | list | `[1, 2, 3]` |
| `:map` | map | `%{key: "val"}` |
| `:any` | any term | anything |
| `:global` | special | HTML global attributes (see section 7) |

**Attribute options:**

| Option | Description |
|---|---|
| `required: true` | Missing this attr = compile error |
| `default: value` | Default when not passed |
| `values: list` | Restricts to enumerated values (compile-time check) |
| `doc: "text"` | Documentation string |
| `examples: list` | Example values for documentation |

---

### 4. Compile-Time Validation

One of the biggest advantages of `attr` declarations: errors are caught at compile
time, not at runtime.

```elixir
attr :variant, :string, required: true, values: ~w(primary secondary)
attr :size, :string, default: "md"

def badge(assigns) do
  ~H"""
  <span class={["badge", "badge-#{@variant}", "badge-#{@size}"]}>{render_slot(@inner_block)}</span>
  """
end
```

```heex
<%!-- Compile error: missing required attribute "variant" --%>
<.badge>Active</.badge>

<%!-- Compile error: invalid value "danger" for attribute "variant" --%>
<.badge variant="danger">Active</.badge>

<%!-- OK --%>
<.badge variant="primary">Active</.badge>
```

This catches typos and invalid values before you even run the application.

---

### 5. Slots

Slots let you pass blocks of HEEx markup into a component, enabling powerful
composition patterns.

#### Default Slot (inner_block)

`inner_block` is the reserved name for the default slot — the content between the
opening and closing tags.

```elixir
slot :inner_block, required: true

def card(assigns) do
  ~H"""
  <div class="card">
    {render_slot(@inner_block)}
  </div>
  """
end
```

```heex
<.card>
  <p>This content goes into the inner_block slot</p>
</.card>
```

#### Named Slots

```elixir
slot :header, required: true
slot :footer

def card(assigns) do
  ~H"""
  <div class="card">
    <div class="card-header">
      {render_slot(@header)}
    </div>
    <div class="card-body">
      {render_slot(@inner_block)}
    </div>
    <div :if={@footer != []} class="card-footer">
      {render_slot(@footer)}
    </div>
  </div>
  """
end
```

```heex
<.card>
  <:header>User Details</:header>

  <p>Name: {@user.name}</p>
  <p>Email: {@user.email}</p>

  <:footer>
    <button>Edit</button>
  </:footer>
</.card>
```

**Checking if a slot was provided:** Named slots are lists (they can be repeated).
An empty slot is `[]`. Use `@footer != []` or `:if={@footer != []}` to
conditionally render.

---

### 6. Slot Attributes and Arguments

Slots can have their own attributes, and they can receive arguments from the
component — enabling the "render prop" pattern.

#### Slot Attributes

```elixir
slot :col, required: true do
  attr :label, :string, required: true
  attr :class, :string
end

attr :rows, :list, required: true

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
        <td :for={col <- @col} class={col[:class]}>
          {render_slot(col, row)}
        </td>
      </tr>
    </tbody>
  </table>
  """
end
```

#### Slot Arguments (The Render Prop Pattern)

The second argument to `render_slot/2` is passed to the slot's `:let` binding.
This allows the component to pass data back to the caller.

```heex
<%!-- The component passes each row to the slot via render_slot(col, row) --%>
<%!-- The caller receives it via :let={user} --%>
<.table rows={@users}>
  <:col :let={user} label="Name">{user.name}</:col>
  <:col :let={user} label="Email">{user.email}</:col>
  <:col :let={user} label="Role" class="font-bold">
    {String.capitalize(to_string(user.role))}
  </:col>
</.table>
```

**How the data flows:**

```
Component:  render_slot(col, row)     ← passes row data INTO the slot
                         │
                         ▼
Template:   <:col :let={user} ...>    ← caller receives it as `user`
              {user.name}             ← caller uses it
            </:col>
```

---

### 7. Global Attributes

The `:global` type allows a component to accept arbitrary HTML attributes (like
`class`, `style`, `data-*`, `aria-*`) without declaring each one.

```elixir
attr :variant, :string, default: "primary"
attr :rest, :global, include: ~w(navigate href target)

slot :inner_block, required: true

def button(assigns) do
  ~H"""
  <button class={["btn", "btn-#{@variant}"]} {@rest}>
    {render_slot(@inner_block)}
  </button>
  """
end
```

```heex
<%!-- All extra attributes are collected in @rest and spread onto the element --%>
<.button variant="primary" id="save-btn" data-confirm="Are you sure?" class="mt-4">
  Save
</.button>

<%!-- With navigate (allowed by include) --%>
<.button navigate={~p"/settings"}>Settings</.button>
```

**How `:global` works:**
- `attr :rest, :global` — accepts standard HTML global attributes (`id`, `class`,
  `style`, `data-*`, `aria-*`, `phx-*`, etc.)
- `include: ~w(navigate href target)` — also accepts these non-global attributes
  (by default, things like `navigate` and `href` are not considered HTML global
  attributes)
- `{@rest}` — spreads all collected attributes onto the element

---

### 8. Organizing Components

Function components can live in several places depending on their scope.

#### CoreComponents (Application-Wide)

Generated by Phoenix, lives at `lib/my_app_web/components/core_components.ex`. This
module is imported into all LiveViews and contains your app's design system.

```elixir
defmodule MyAppWeb.CoreComponents do
  use Phoenix.Component

  # These are available everywhere as <.button>, <.input>, etc.

  attr :type, :string, default: "button"
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} class="btn" {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  # ... <.input>, <.table>, <.header>, <.flash>, <.modal>, etc.
end
```

#### Private Components in a LiveView (Lesson-Specific)

Use `defp` for components only needed in one LiveView.

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <.stat_card label="Users" value={@user_count} />
    <.stat_card label="Revenue" value={"$#{@revenue}"} />
    """
  end

  # Only used in this LiveView
  defp stat_card(assigns) do
    ~H"""
    <div class="stat-card">
      <dt>{@label}</dt>
      <dd>{@value}</dd>
    </div>
    """
  end
end
```

#### Shared Modules (Domain-Specific)

For components shared across multiple LiveViews but not app-wide.

```elixir
defmodule MyAppWeb.ChartComponents do
  use Phoenix.Component

  attr :data, :list, required: true
  attr :height, :integer, default: 200

  def bar_chart(assigns) do
    ~H"""
    <div class="chart" style={"height: #{@height}px"}>
      <div :for={point <- @data} class="bar" style={"height: #{point.value}%"}>
        {point.label}
      </div>
    </div>
    """
  end
end

# Usage in a LiveView (import or use fully qualified name)
import MyAppWeb.ChartComponents
# then: <.bar_chart data={@chart_data} />

# Or without importing:
<MyAppWeb.ChartComponents.bar_chart data={@chart_data} />
```

---

### 9. CoreComponents Walkthrough

Phoenix generates a `CoreComponents` module with several essential components.
Understanding these is important because they are used throughout every generated
Phoenix app.

```elixir
# <.input> — renders form inputs with labels, errors, and various types
<.input field={@form[:email]} type="email" label="Email" />
<.input field={@form[:role]} type="select" label="Role" options={["Admin", "User"]} />

# <.button> — styled button with loading states
<.button phx-click="save">Save</.button>
<.button variant="secondary">Cancel</.button>

# <.table> — data table with slot-based columns
<.table id="users" rows={@users}>
  <:col :let={user} label="Name">{user.name}</:col>
  <:col :let={user} label="Email">{user.email}</:col>
</.table>

# <.header> — page header with optional action slots
<.header>
  Users
  <:actions>
    <.link patch={~p"/users/new"}>
      <.button>New User</.button>
    </.link>
  </:actions>
</.header>

# <.flash_group> — renders flash messages
<.flash_group flash={@flash} />

# <.modal> — accessible modal dialog
<.modal id="confirm-modal" show>
  <p>Are you sure?</p>
</.modal>
```

These components use the patterns covered in this lesson: `attr`, `slot`,
`:global` attributes, and slot arguments.

---

### 10. Function Components vs LiveComponents

| Aspect | Function Component | LiveComponent |
|---|---|---|
| State | None (stateless) | Own assigns (stateful) |
| Process | None (runs in parent) | Shares parent's process |
| Lifecycle | None | mount, update, render |
| Re-renders when | Parent re-renders with changed assigns | Parent sends changed props, or `send_update` |
| Events | Handled by parent LiveView | Handled by component (via `@myself`) |
| Use for | Display, layout, reusable markup | Isolated forms, complex interactive widgets |
| Syntax | `<.my_comp>` | `<.live_component module={MyComp} id="x" />` |

**Rule of thumb:** Start with function components. They are simpler, faster to write,
and easier to reason about. Only upgrade to a LiveComponent when you need:
1. **Isolated state** that should not be in the parent's assigns
2. **Component-scoped event handling** (via `@myself`)
3. **Independent re-rendering** (via `send_update`)

LiveComponents are covered in depth in Lesson 11.

---

## Common Pitfalls

1. **Forgetting `render_slot(@inner_block)`** — If you declare a default slot but
   never call `render_slot/1`, the content between the tags is silently discarded.

2. **Checking named slots with `@header` instead of `@header != []`** — Named
   slots are always a list. An empty slot is `[]`, which is truthy in Elixir. Use
   `@header != []` to check if content was provided.

3. **Using LiveComponent when a function component suffices** — If the component
   has no internal state and no component-scoped events, it should be a function
   component. LiveComponents add lifecycle overhead for no benefit in display-only
   cases.

4. **Not declaring `attr` and `slot`** — Without declarations, you lose compile-time
   validation, documentation, and default values. Always declare attributes and slots
   even for simple components.

5. **Passing too many attrs instead of composing with slots** — If you find yourself
   with 10+ attributes, consider whether slots would make the component more
   flexible and the call site more readable.

6. **Confusing `:global` include behavior** — Without `include`, `:global` only
   accepts standard HTML global attributes. Attributes like `navigate`, `href`, and
   `method` must be explicitly included.

---

## Exercises

1. Build a `<.badge>` function component with `attr :variant` (`:info`, `:warning`,
   `:error`) and an `inner_block` slot for the text
2. Create a `<.card>` component with named slots `:header`, `:body`, and `:footer`,
   where `:footer` is optional
3. Implement a `<.data_table>` component with a `:col` slot that uses slot arguments
   (`:let`) to render each row — similar to the CoreComponents `<.table>`
4. Refactor a LiveView with repeated markup into private `defp` function components
5. Create a `<.nav_link>` component that uses `attr :rest, :global, include:
   ~w(navigate patch href)` to support both LiveView navigation and regular links
