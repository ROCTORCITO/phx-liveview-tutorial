# Lesson 5: Navigation & Routing

## Overview

LiveView has its own navigation system that operates over the existing WebSocket
connection. Understanding the difference between **patch** and **navigate** — and
when to use each — is fundamental to building LiveView applications that feel fast,
preserve state correctly, and produce bookmarkable URLs.

The key insight: a LiveView process is tied to a WebSocket connection. Patching keeps
the same process alive (fast, preserves state). Navigating kills the old process and
starts a new one (clean slate).

**Source file:** `lib/liveview_lab_web/live/lesson5_navigation_live.ex`

---

## Core Concepts

### 1. Router Configuration

LiveView routes are defined in the Phoenix router alongside regular controller routes.

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # ... pipelines ...

  scope "/", MyAppWeb do
    pipe_through :browser

    # Basic LiveView route
    live "/dashboard", DashboardLive

    # Route with path parameter
    live "/users/:id", UserLive

    # Route with optional action
    live "/posts", PostLive.Index, :index
    live "/posts/new", PostLive.Index, :new
    live "/posts/:id/edit", PostLive.Index, :edit

    # Grouped routes sharing on_mount hooks
    live_session :authenticated, on_mount: [MyAppWeb.AuthHook] do
      live "/settings", SettingsLive
      live "/profile", ProfileLive
      live "/admin", AdminLive
    end

    live_session :public do
      live "/about", AboutLive
      live "/contact", ContactLive
    end
  end
end
```

Path parameters (`:id`) are passed to `mount/3` and `handle_params/3` as the
first argument.

---

### 2. Patch vs Navigate

This is the most important distinction in LiveView navigation.

```
┌──────────────────────────────────────────────────────────────────┐
│                      PATCH                                       │
│  Same LiveView module → Same process stays alive                 │
│  Calls: handle_params/3 (NOT mount/3)                           │
│  Use for: tabs, filters, pagination, sorting within one view     │
│                                                                  │
│  <.link patch={~p"/users?sort=name"}>Sort by name</.link>       │
│  push_patch(socket, to: ~p"/users?page=2")                      │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                     NAVIGATE                                     │
│  Different LiveView module (or forced new process)               │
│  Calls: mount/3 → handle_params/3 (full lifecycle)              │
│  Use for: moving between different pages/views                   │
│                                                                  │
│  <.link navigate={~p"/settings"}>Settings</.link>               │
│  push_navigate(socket, to: ~p"/settings")                       │
└──────────────────────────────────────────────────────────────────┘
```

**Lifecycle comparison:**

| Action | mount/3 | handle_params/3 | Process |
|---|---|---|---|
| First page load | Yes | Yes (after mount) | New |
| Patch | No | Yes | Same |
| Navigate | Yes | Yes (after mount) | New |
| Browser back/forward | No (if same LV) | Yes | Same |

```heex
<%!-- In templates --%>

<%!-- Patch: stays in the same LiveView, updates URL, calls handle_params --%>
<.link patch={~p"/products?category=electronics"}>Electronics</.link>
<.link patch={~p"/products?category=books&sort=price"}>Books by price</.link>

<%!-- Navigate: new LiveView process, full mount --%>
<.link navigate={~p"/settings"}>Settings</.link>
<.link navigate={~p"/users/#{@user.id}"}>View Profile</.link>
```

---

### 3. handle_params/3

The callback that makes LiveView URLs meaningful. It is called:
1. After `mount/3` on the initial page load
2. On every `patch` (URL change within the same LiveView)
3. When the user clicks browser back/forward buttons

```elixir
# handle_params receives:
#   1. params — URL path and query parameters (all strings)
#   2. uri — the full URL as a string
#   3. socket — the current socket

def handle_params(params, _uri, socket) do
  sort_by = params["sort"] || "name"
  sort_order = params["order"] || "asc"
  page = String.to_integer(params["page"] || "1")

  users = Accounts.list_users(sort_by: sort_by, sort_order: sort_order, page: page)

  {:noreply,
   assign(socket,
     users: users,
     sort_by: sort_by,
     sort_order: sort_order,
     page: page
   )}
end
```

**Why handle_params matters:**
- Makes views **bookmarkable** — the URL captures the full view state
- Supports **browser back/forward** — previous states are URL-encoded
- Enables **link sharing** — send someone a URL with filters pre-applied
- Keeps the **URL as the single source of truth** for view state

---

### 4. Programmatic Navigation

Navigate from within `handle_event` or `handle_info` callbacks.

```elixir
# push_patch — same LiveView, triggers handle_params
def handle_event("filter", %{"category" => category}, socket) do
  {:noreply, push_patch(socket, to: ~p"/products?category=#{category}")}
end

# push_navigate — different LiveView (or force new process), triggers mount
def handle_event("go_to_settings", _params, socket) do
  {:noreply, push_navigate(socket, to: ~p"/settings")}
end

# Conditional navigation
def handle_event("save", params, socket) do
  case Products.create(params) do
    {:ok, product} ->
      {:noreply,
       socket
       |> put_flash(:info, "Product created!")
       |> push_navigate(to: ~p"/products/#{product.id}")}

    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

**`push_patch` vs `push_navigate`** follow the same rules as `<.link patch>` vs
`<.link navigate>`:
- `push_patch` = same process, calls `handle_params`
- `push_navigate` = new process, calls `mount` then `handle_params`

---

### 5. live_session

Groups routes that share `on_mount` hooks. Navigation between different
`live_session` groups requires a full page reload (new HTTP request + new
WebSocket). Navigation within the same `live_session` stays on the WebSocket.

```elixir
live_session :authenticated,
  on_mount: [{MyAppWeb.AuthHook, :ensure_authenticated}],
  session: %{"locale" => "en"} do

  live "/dashboard", DashboardLive
  live "/profile", ProfileLive
end

live_session :admin,
  on_mount: [{MyAppWeb.AuthHook, :ensure_admin}] do

  live "/admin/users", Admin.UserLive
  live "/admin/settings", Admin.SettingsLive
end
```

```elixir
# The on_mount hook
defmodule MyAppWeb.AuthHook do
  import Phoenix.LiveView

  # The atom (:ensure_authenticated) is passed as the first argument
  def on_mount(:ensure_authenticated, _params, session, socket) do
    if session["user_id"] do
      user = Accounts.get_user!(session["user_id"])
      {:cont, assign(socket, current_user: user)}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end

  def on_mount(:ensure_admin, params, session, socket) do
    case on_mount(:ensure_authenticated, params, session, socket) do
      {:cont, socket} ->
        if socket.assigns.current_user.role == :admin do
          {:cont, socket}
        else
          {:halt, redirect(socket, to: "/unauthorized")}
        end

      halt ->
        halt
    end
  end
end
```

**Key rules:**
- Navigating from `:authenticated` to `:admin` = full page reload
- Navigating within `:authenticated` = WebSocket (fast)
- `on_mount` hooks run before `mount/3` on every page load within the session
- Use `{:halt, redirect(...)}` to block unauthorized access

---

### 6. URL-Driven State Patterns

The recommended pattern is to use the URL as the source of truth for view state.
This makes your views bookmarkable, shareable, and compatible with browser
back/forward.

```elixir
# Mount sets up the socket but defers data loading to handle_params
def mount(_params, _session, socket) do
  {:ok, assign(socket, loading: true)}
end

# handle_params is the ONLY place where URL state is read and applied
def handle_params(params, _uri, socket) do
  sort_by = params["sort"] || "name"
  order = params["order"] || "asc"
  page = String.to_integer(params["page"] || "1")
  search = params["q"] || ""

  %{entries: users, total_pages: total_pages} =
    Accounts.list_users(
      sort_by: sort_by,
      order: order,
      page: page,
      search: search
    )

  {:noreply,
   assign(socket,
     users: users,
     sort_by: sort_by,
     order: order,
     page: page,
     search: search,
     total_pages: total_pages,
     loading: false
   )}
end
```

**Building navigation links that preserve existing params:**

```heex
<%!-- Sorting: changes sort, resets page to 1 --%>
<.link patch={~p"/users?sort=name&order=asc&page=1&q=#{@search}"}>
  Name
</.link>

<%!-- Pagination: changes page, preserves sort and search --%>
<.link patch={~p"/users?sort=#{@sort_by}&order=#{@order}&page=#{@page + 1}&q=#{@search}"}>
  Next page
</.link>

<%!-- Search form: patches with the query --%>
<form phx-change="search" phx-submit="search">
  <input name="q" value={@search} phx-debounce="300" />
</form>
```

```elixir
def handle_event("search", %{"q" => query}, socket) do
  {:noreply,
   push_patch(socket,
     to: ~p"/users?sort=#{socket.assigns.sort_by}&order=#{socket.assigns.order}&page=1&q=#{query}"
   )}
end
```

---

### 7. Query Parameter Handling

All URL parameters arrive as strings. Handle defaults and conversion carefully.

```elixir
def handle_params(params, _uri, socket) do
  # String params with defaults
  sort = params["sort"] || "name"
  direction = params["direction"] || "asc"

  # Integer conversion with defaults
  page = String.to_integer(params["page"] || "1")
  per_page = String.to_integer(params["per_page"] || "20")

  # Boolean params (presence-based)
  show_archived = params["archived"] == "true"

  # Multi-value params (from checkboxes or multi-select)
  # URL: ?tags[]=elixir&tags[]=phoenix
  tags = params["tags"] || []

  # Validation: clamp to acceptable ranges
  page = max(page, 1)
  per_page = min(per_page, 100)

  {:noreply, assign(socket, sort: sort, page: page, per_page: per_page)}
end
```

---

## Common Pitfalls

1. **Using navigate when patch would preserve state** — If you are staying in the
   same LiveView (e.g., changing filters), use `patch`. Using `navigate` will kill
   the process and lose all transient state (open modals, scroll position, etc.).

2. **Not implementing handle_params** — If your LiveView has URL parameters but no
   `handle_params/3`, the params are ignored after mount. Patches won't update the
   view, and browser back/forward won't work correctly.

3. **Storing state only in assigns, not in the URL** — If a filter is stored only
   in `socket.assigns` and not in the URL, users cannot bookmark or share the
   filtered view, and browser back/forward won't restore it. Use `push_patch` to
   encode important view state in the URL.

4. **Forgetting that handle_params runs after mount** — On the initial page load,
   the call order is `mount/3` then `handle_params/3`. If you load data in both
   places, you may do redundant work. The recommended pattern is: set up the socket
   in `mount`, load data in `handle_params`.

5. **Not handling missing or invalid query params** — Always provide defaults.
   `String.to_integer(nil)` will crash. Use `params["page"] || "1"` before
   converting.

6. **Navigating between different live_sessions and expecting WebSocket continuity**
   — Crossing `live_session` boundaries triggers a full page reload. Group related
   routes in the same `live_session` to keep navigation over the WebSocket.

---

## Exercises

1. Build a product listing with sort (by name, price) and pagination as URL query
   params using `push_patch`
2. Implement a tabbed interface where each tab is a different URL path parameter
   (e.g., `/settings/profile`, `/settings/security`) using `handle_params`
3. Create a search page where the query is a URL param (`?q=elixir`), so the search
   results are bookmarkable
4. Set up two `live_session` groups (`:public` and `:authenticated`) with an
   `on_mount` hook that checks for a user session
5. Build a detail view (`/items/:id`) that loads item data in `handle_params` and
   supports browser back/forward between items
