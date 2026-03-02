# Lesson 3: Assigns & Reactivity

## Overview

Assigns are LiveView's state management mechanism. Every piece of data your LiveView
needs to render lives in `socket.assigns`, a plain Elixir map. When you change an assign,
LiveView's change tracking automatically determines which parts of the template are
affected, re-evaluates only those parts, and sends a minimal diff to the browser.

This lesson covers how assigns work, how change tracking optimizes rendering, how to
build forms (both with and without Ecto), and the reactive patterns that keep LiveView
code clean and performant.

**Source file:** `lib/liveview_lab_web/live/lesson3_assigns_reactivity_live.ex`

---

## Core Concepts

### 1. The Assigns Map

`socket.assigns` is a plain Elixir map. You read from it, but you never write to it
directly — you use helper functions that update the socket and notify the change tracking
system.

```elixir
# assign/2 — set one or more assigns with a keyword list
socket = assign(socket, count: 0, title: "My Page")

# assign/3 — set a single assign with key and value
socket = assign(socket, :count, 0)

# assign/2 with a map — useful for dynamic keys or merging
socket = assign(socket, %{count: 0, title: "My Page"})

# assign_new/3 — set a default value ONLY if the key does not already exist
socket = assign_new(socket, :count, fn -> expensive_default() end)
# The function is only called if :count is not already in assigns.
# This is useful in components that receive assigns from a parent —
# you can set defaults without overwriting values the parent passed in.

# Reading assigns in Elixir code
socket.assigns.count      # direct access
socket.assigns[:count]    # safe access (returns nil if missing)

# Reading assigns in templates
# @count — shorthand for assigns.count inside ~H sigils
```

**`assign_new/3` in depth:**

```elixir
# In a LiveComponent or helper function:
def update(assigns, socket) do
  socket =
    socket
    |> assign(assigns)                              # Parent's assigns always applied
    |> assign_new(:expanded, fn -> false end)        # Default only if parent didn't pass it
    |> assign_new(:metadata, fn -> load_metadata(assigns.id) end)  # Lazy — only loads if needed

  {:ok, socket}
end
```

The function argument to `assign_new/3` is lazy — it is only called if the key is absent.
This matters when the default involves a database query or other expensive computation.

---

### 2. Change Tracking

LiveView's change tracking is automatic and assign-level. When you call `assign/2`, LiveView
records which keys changed. At render time, the `~H` sigil (compiled at build time) knows
which assigns each template expression depends on. Only expressions referencing changed
assigns are re-evaluated.

```elixir
def render(assigns) do
  ~H"""
  <div>
    <h1>{@title}</h1>              <!-- depends on @title -->
    <p>Count: {@count}</p>         <!-- depends on @count -->
    <p>Score: {@count * 10}</p>    <!-- depends on @count -->
    <footer>{@footer_text}</footer> <!-- depends on @footer_text -->
  </div>
  """
end

def handle_event("increment", _, socket) do
  # Only @count changes.
  # LiveView re-evaluates ONLY the two expressions that reference @count.
  # @title and @footer_text expressions are skipped entirely.
  {:noreply, assign(socket, count: socket.assigns.count + 1)}
end
```

**How it works internally:**

1. The `~H` sigil is compiled into a data structure that splits the template into
   **static parts** (literal HTML that never changes) and **dynamic parts** (expressions
   referencing assigns).
2. Each dynamic part is tagged with the assigns it depends on.
3. On render, LiveView checks which assigns have been marked as changed.
4. Only dynamic parts whose dependencies include a changed assign are re-evaluated.
5. The diff sent to the client contains only the new values of re-evaluated parts.

**No manual optimization needed.** There is no `shouldComponentUpdate`, no `useMemo`, no
memoization decorators. The compiler handles it. Your job is to structure templates so
that volatile assigns do not accidentally trigger re-evaluation of expensive expressions.

**Template structuring tip:**

```elixir
# Bad — the entire list comprehension re-evaluates when @selected_id changes,
# because the expression references both @items and @selected_id
~H"""
<ul>
  <li :for={item <- @items} class={if item.id == @selected_id, do: "active"}>
    {item.name}
  </li>
</ul>
"""

# Better — extract into a function component so change tracking is more granular
~H"""
<ul>
  <.item_row :for={item <- @items} item={item} selected={item.id == @selected_id} />
</ul>
"""

defp item_row(assigns) do
  ~H"""
  <li class={if @selected, do: "active"}>{@item.name}</li>
  """
end
```

In the "better" version, each `item_row` component tracks its own assigns independently.
If only `@selected` changes for one row, only that row's expression is re-evaluated.

---

### 3. Forms Without Ecto

LiveView forms can work without Ecto schemas or changesets. The `to_form/1` function
accepts a plain map of parameters and returns a `%Phoenix.HTML.Form{}` struct that
the `<.form>` and `<.input>` components understand.

```elixir
def mount(_params, _session, socket) do
  # Initialize form with default values
  form =
    %{"name" => "", "email" => "", "age" => ""}
    |> to_form(as: :profile)
  # as: :profile means form fields will be nested under "profile" key
  # e.g., params = %{"profile" => %{"name" => "Alice", ...}}

  {:ok, assign(socket, form: form, submitted: false)}
end
```

**Template:**

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} type="text" label="Name" />
  <.input field={@form[:email]} type="email" label="Email" />
  <.input field={@form[:age]} type="number" label="Age" />

  <button type="submit">Save</button>
</.form>
```

**Handling validation and submission:**

```elixir
def handle_event("validate", %{"profile" => params}, socket) do
  errors = validate_profile(params)

  form =
    params
    |> to_form(as: :profile, errors: errors, action: :validate)
  # action: :validate tells CoreComponents to show errors
  # Without an action, <.input> suppresses error display

  {:noreply, assign(socket, form: form)}
end

def handle_event("save", %{"profile" => params}, socket) do
  errors = validate_profile(params)

  if errors == [] do
    # No errors — process the data
    # (save to database, send email, etc.)
    {:noreply,
     socket
     |> assign(submitted: true)
     |> put_flash(:info, "Profile saved!")}
  else
    form =
      params
      |> to_form(as: :profile, errors: errors, action: :validate)

    {:noreply, assign(socket, form: form)}
  end
end

# Manual validation — returns a keyword list of errors
defp validate_profile(params) do
  errors = []

  errors =
    if String.trim(params["name"]) == "" do
      [{:name, {"can't be blank", []}} | errors]
    else
      errors
    end

  errors =
    if !String.match?(params["email"], ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      [{:email, {"must be a valid email address", []}} | errors]
    else
      errors
    end

  errors =
    case Integer.parse(params["age"] || "") do
      {age, ""} when age > 0 and age < 150 -> errors
      _ -> [{:age, {"must be a number between 1 and 149", []}} | errors]
    end

  errors
end
```

**Error format:** Errors must be a keyword list where each entry is
`{field_atom, {message_string, metadata_list}}`. The metadata list is typically empty
(`[]`) for manual validation but is used by Ecto for interpolation
(e.g., `{"should be at least %{count} characters", [count: 3]}`).

---

### 4. Forms With Ecto Changesets

When you have an Ecto schema, changesets provide built-in validation. The `to_form/1`
function accepts a changeset directly.

```elixir
defmodule MyApp.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :name, :string
    field :email, :string
    field :age, :integer
    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_number(:age, greater_than: 0, less_than: 150)
  end
end
```

**In the LiveView:**

```elixir
def mount(_params, _session, socket) do
  profile = %Profile{}
  changeset = Profile.changeset(profile, %{})
  form = to_form(changeset)

  {:ok, assign(socket, form: form, profile: profile)}
end

def handle_event("validate", %{"profile" => params}, socket) do
  changeset =
    socket.assigns.profile
    |> Profile.changeset(params)
    |> Map.put(:action, :validate)
  # Setting :action to :validate tells to_form to include errors.
  # Without an action, errors are suppressed (the user hasn't "tried" yet).

  {:noreply, assign(socket, form: to_form(changeset))}
end

def handle_event("save", %{"profile" => params}, socket) do
  case Accounts.create_profile(params) do
    {:ok, profile} ->
      {:noreply,
       socket
       |> put_flash(:info, "Profile created!")
       |> redirect(to: ~p"/profiles/#{profile}")}

    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

The key difference from schemaless forms: Ecto changesets carry their own validations
and error state. You do not need to build the error keyword list manually — the
changeset contains it. Setting the `:action` field on the changeset controls when
errors become visible to `to_form`.

---

### 5. The `<.input>` Component

`<.input>` is a function component defined in your project's `CoreComponents` module
(auto-generated by `mix phx.new`). It is a convenience wrapper that handles rendering
labels, input elements, and error messages consistently.

```heex
<!-- Text input -->
<.input field={@form[:name]} type="text" label="Full Name" />

<!-- Email input -->
<.input field={@form[:email]} type="email" label="Email Address" />

<!-- Password input -->
<.input field={@form[:password]} type="password" label="Password" />

<!-- Number input -->
<.input field={@form[:age]} type="number" label="Age" min="1" max="149" />

<!-- Textarea -->
<.input field={@form[:bio]} type="textarea" label="Biography" rows="5" />

<!-- Select dropdown -->
<.input
  field={@form[:role]}
  type="select"
  label="Role"
  options={["Admin": "admin", "User": "user", "Guest": "guest"]}
/>

<!-- Checkbox -->
<.input field={@form[:terms]} type="checkbox" label="I agree to the terms" />
```

**How `<.input>` renders errors:**

The default `CoreComponents` implementation gates error display using `used_input?/1`
(Phoenix 1.7.12+) or the presence of an `:action` on the form. This prevents showing
validation errors before the user has interacted with the field.

```elixir
# Inside CoreComponents (simplified)
def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
  errors = if used_input?(field), do: field.errors, else: []
  # ...renders label, input element, and error messages
end
```

`used_input?/1` returns `true` once the field has been changed by the user (via
`phx-change` events). Before that, errors are hidden — even if the changeset contains
them. This gives a better UX: the user sees errors only after they have interacted with
a field or submitted the form.

**The `field` assign:**

`field={@form[:name]}` is shorthand that extracts the field's name, value, errors, and
metadata from the form struct. It is equivalent to:

```elixir
%Phoenix.HTML.FormField{
  id: "profile_name",
  name: "profile[name]",
  value: "Alice",
  errors: [{"can't be blank", []}],
  field: :name,
  form: %Phoenix.HTML.Form{...}
}
```

---

### 6. Reactive Patterns

LiveView's reactivity model is simpler than client-side frameworks because all state
lives in one place (assigns) and updates follow a clear path: event -> handle ->
assign -> render. Here are patterns to keep it clean.

**Compute derived state in event handlers, not in render:**

```elixir
# Bad — expensive computation runs on EVERY render
def render(assigns) do
  ~H"""
  <p>Total: {Enum.sum(Enum.map(@items, & &1.price))}</p>
  """
end

# Good — compute once when data changes, store the result
def handle_event("add_item", %{"item" => params}, socket) do
  items = [parse_item(params) | socket.assigns.items]
  total = Enum.sum(Enum.map(items, & &1.price))

  {:noreply, assign(socket, items: items, total: total)}
end

def render(assigns) do
  ~H"""
  <p>Total: {@total}</p>
  """
end
```

**Do not store derived data that can be computed from other assigns:**

```elixir
# Problematic — @count and @items can get out of sync
socket
|> assign(items: new_items)
|> assign(count: length(new_items))

# Better — compute in the event handler where both change together
# Or even better — use a function component that computes it:
defp item_count(assigns) do
  ~H"""
  <span>{length(@items)} items</span>
  """
end
```

The caveat is that `length(@items)` in the template re-evaluates on every render where
`@items` changed. For large lists, precomputing in the handler is faster. For small lists,
inline computation is fine and keeps code simpler.

**Use `assign_new/3` for defaults in reusable components:**

```elixir
def update(assigns, socket) do
  socket =
    socket
    |> assign(assigns)
    |> assign_new(:show_header, fn -> true end)
    |> assign_new(:class, fn -> "" end)

  {:ok, socket}
end
```

**Pattern: resetting form state after successful submission:**

```elixir
def handle_event("save", %{"profile" => params}, socket) do
  case save_profile(params) do
    {:ok, _profile} ->
      fresh_form = %{"name" => "", "email" => ""} |> to_form(as: :profile)

      {:noreply,
       socket
       |> assign(form: fresh_form)
       |> put_flash(:info, "Saved!")}

    {:error, errors} ->
      form = params |> to_form(as: :profile, errors: errors, action: :validate)
      {:noreply, assign(socket, form: form)}
  end
end
```

**Pattern: assign pipelines for clarity:**

```elixir
def handle_event("apply_filters", %{"filters" => filter_params}, socket) do
  {:noreply,
   socket
   |> assign(filters: filter_params)
   |> assign(page: 1)                              # Reset to first page
   |> load_results(filter_params, 1)                # Fetch filtered data
   |> assign(filter_form: to_form(filter_params, as: :filters))}
end

defp load_results(socket, filters, page) do
  {results, total} = Search.query(filters, page: page, per_page: 20)
  assign(socket, results: results, total_count: total)
end
```

Chaining `assign` calls in a pipeline makes the data flow explicit and easy to follow.

---

## Common Pitfalls

1. **Mutating assigns directly** — Never write to `socket.assigns` directly. This
   bypasses change tracking and the template will not update:
   ```elixir
   # Wrong — bypasses change tracking
   put_in(socket.assigns.count, 42)
   %{socket | assigns: Map.put(socket.assigns, :count, 42)}

   # Correct
   assign(socket, count: 42)
   ```

2. **Large, frequently-changing assigns** — If you store a list of 10,000 items in an
   assign and update it every second, LiveView must diff the entire list on each render.
   Use streams for large collections, or break large assigns into smaller ones so change
   tracking can skip unchanged parts.

3. **Forgetting `to_form`** — The `<.form>` component expects a `%Phoenix.HTML.Form{}`
   struct, not a raw map or changeset. Always wrap with `to_form/1`:
   ```elixir
   # Wrong — template will error
   assign(socket, form: %{"name" => "Alice"})

   # Wrong — changeset is not a form
   assign(socket, form: Profile.changeset(%Profile{}, %{}))

   # Correct
   assign(socket, form: to_form(%{"name" => "Alice"}, as: :profile))
   assign(socket, form: to_form(changeset))
   ```

4. **Not gating errors with action or `used_input?`** — If you pass errors to `to_form`
   without setting an `:action`, errors may not display (depending on your CoreComponents
   implementation). If you show errors immediately without waiting for user interaction,
   the form shows a wall of errors on initial render:
   ```elixir
   # Shows errors only after user interaction
   to_form(params, as: :profile, errors: errors, action: :validate)

   # The default <.input> component in CoreComponents uses used_input?/1
   # to further gate error display per-field
   ```

5. **Calling `to_form` in `render/1`** — `to_form` creates a new struct every time. If
   called in render, it runs on every re-render. Call it in event handlers and store the
   result in assigns:
   ```elixir
   # Bad — creates a new form struct on every render
   def render(assigns) do
     form = to_form(assigns.params)
     assigns = assign(assigns, form: form)
     ~H"""..."""
   end

   # Good — create the form in event handlers
   def handle_event("validate", %{"profile" => params}, socket) do
     {:noreply, assign(socket, form: to_form(params, as: :profile))}
   end
   ```

6. **Storing the same data in multiple assigns** — If you store `@items` and also
   `@filtered_items` and `@sorted_items`, you have three copies in memory and three
   things to keep in sync. Derive filtered/sorted views in the handler and store only
   the result the template needs.

---

## Exercises

1. Build a form without Ecto that collects a username and bio. Validate that the username
   is at least 3 characters and the bio is at most 200 characters. Show errors inline
   using `<.input>` and `to_form` with manual error keyword lists.
2. Add `assign_new/3` to set a default `:theme` assign to `"light"`. Write a toggle
   button that switches between `"light"` and `"dark"` and applies a CSS class based
   on the assign. Confirm that `assign_new` does not overwrite the value after the
   toggle.
3. Create a LiveView with a `@items` list and a `@search` assign. On `phx-change` of a
   search input, filter the items and store the result in `@filtered_items`. Observe
   the WebSocket frames to confirm that only the list portion of the template is
   re-rendered when `@filtered_items` changes.
4. Intentionally put an `Enum.sum/1` call directly in the template referencing a large
   list assign. Then refactor it to precompute the sum in the event handler. Compare the
   diff sizes in the browser's WebSocket inspector.
