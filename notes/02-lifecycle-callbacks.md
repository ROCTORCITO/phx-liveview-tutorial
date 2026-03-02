# Lesson 2: Lifecycle Callbacks

## Overview

A LiveView process follows a strict sequence of callbacks from birth to death. Understanding
this sequence is essential — putting code in the wrong callback causes bugs that range from
wasted work to silent data loss.

Every LiveView process starts with `mount`, optionally receives URL changes via
`handle_params`, renders, and then enters a loop of event handling and re-rendering until
the connection closes. Each callback has a specific signature, a specific purpose, and
specific constraints.

**Source file:** `lib/liveview_lab_web/live/lesson2_lifecycle_live.ex`

---

## Core Concepts

### 1. Callback Sequence

The lifecycle of a LiveView process follows this order:

```text
                          (initial page load)
                                 |
                                 v
                           +----------+
                           | mount/3  |  <-- called once per process
                           +----------+
                                 |
                                 v
                        +----------------+
                        | handle_params/3|  <-- called after mount
                        +----------------+
                                 |
                                 v
                           +----------+
                           | render/1 |  <-- produces HTML/diffs
                           +----------+
                                 |
                                 v
                     +-----------------------+
                     | Event/Message Loop    |
                     |                       |
                     | handle_event/3        |  <-- user interactions
                     | handle_info/2         |  <-- OTP messages
                     | handle_async/3        |  <-- start_async results
                     | handle_params/3       |  <-- live_patch URL changes
                     |         |             |
                     |         v             |
                     |     render/1          |
                     |         |             |
                     |    (loop back)        |
                     +-----------------------+
                                 |
                          (disconnect/crash)
                                 |
                                 v
                         +--------------+
                         | terminate/2  |  <-- best-effort cleanup
                         +--------------+
```

Key points:
- `mount/3` always runs first
- `handle_params/3` always runs immediately after `mount/3`
- `render/1` runs after every state change
- `handle_event/3`, `handle_info/2`, and `handle_params/3` (on patch) can interleave
  freely during the process lifetime
- `terminate/2` is called on graceful shutdown but is **not guaranteed**

---

### 2. `mount/3`

**Signature:** `mount(params, session, socket)`

`mount/3` is the entry point for every LiveView process. It is called once per process,
but remember that the disconnected and connected phases are separate processes — so
`mount/3` runs twice for every page load (once in each process).

```elixir
def mount(%{"id" => id}, session, socket) do
  # params: URL path parameters (from the router)
  #   e.g., /posts/:id -> %{"id" => "42"}
  #   Only path params, NOT query string params (those come in handle_params)

  # session: Plug session data (set by the Plug pipeline)
  #   e.g., %{"current_user_id" => 123, "_csrf_token" => "abc"}
  #   This is how you authenticate — look up the user from the session

  # socket: %Phoenix.LiveView.Socket{} with default assigns

  user = Accounts.get_user!(session["current_user_id"])
  post = Blog.get_post!(id)

  socket =
    socket
    |> assign(user: user, post: post)
    |> assign(edit_mode: false)

  # Guard expensive/side-effectful work behind connected?/1
  socket =
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "post:#{id}")
      socket
    else
      socket
    end

  {:ok, socket}
end
```

**Rules for `mount/3`:**

- Always returns `{:ok, socket}` or `{:ok, socket, opts}` where `opts` can include
  `temporary_assigns`, `layout`, etc.
- `params` contains **only** path parameters from the router, not query string parameters.
  Query params arrive in `handle_params/3`.
- `session` contains data from the Plug session. This is your authentication bridge —
  the session is set by plugs in the HTTP pipeline before the LiveView process starts.
- Guard PubSub subscriptions, timers, and async work behind `connected?(socket)` to
  avoid wasting work in the disconnected phase.

---

### 3. `handle_params/3`

**Signature:** `handle_params(params, uri, socket)`

`handle_params/3` is called in two situations:
1. **Immediately after `mount/3`** — on every page load
2. **On every `live_patch`** — when the URL changes without a full page navigation

It is **not** called on `live_navigate` or `navigate`, because those start a new LiveView
process (which gets its own `mount` + `handle_params` cycle).

```elixir
def handle_params(params, uri, socket) do
  # params: merged path + query parameters
  #   e.g., /posts/42?tab=comments&page=2
  #   -> %{"id" => "42", "tab" => "comments", "page" => "2"}

  # uri: the full URI as a string
  #   e.g., "http://localhost:4000/posts/42?tab=comments&page=2"

  tab = params["tab"] || "details"
  page = String.to_integer(params["page"] || "1")

  socket =
    socket
    |> assign(current_tab: tab, page: page)
    |> load_tab_data(tab, page)

  {:noreply, socket}
end
```

**Use `handle_params/3` for URL-driven state:**

```elixir
# In the template — live_patch changes URL without full reload
<.link patch={~p"/posts/#{@post}?tab=comments"}>Comments</.link>
<.link patch={~p"/posts/#{@post}?tab=details"}>Details</.link>

# This triggers handle_params with the new query params.
# The LiveView process stays alive — no remount.
```

Common uses:
- Tab selection
- Pagination
- Search filters
- Sort order
- Modal open/close (URL-backed modals)

**Why not use `handle_event` for this?** Because URL state should be in the URL. If the
user bookmarks the page or shares the link, `handle_params` ensures the state is restored
from the URL. `handle_event` would lose the state on page reload.

---

### 4. `render/1`

**Signature:** `render(assigns)`

`render/1` is called after every state change — after `mount`, after `handle_params`,
after every `handle_event`, and after every `handle_info`. It is a **pure function** of
the assigns: given the same assigns, it always produces the same output.

```elixir
def render(assigns) do
  ~H"""
  <div>
    <h1>{@title}</h1>
    <p>Count: {@count}</p>

    <button phx-click="increment">+1</button>

    <.tab_content tab={@current_tab} data={@tab_data} />
  </div>
  """
end
```

**Rules for `render/1`:**

- Must return a `~H` sigil (HEEx template) or call a component that does.
- Should be a pure function — no side effects, no database calls, no message sends.
  Compute everything in event handlers and store it in assigns.
- Change tracking optimizes it automatically. Only expressions referencing changed
  assigns are re-evaluated.
- If you define a `render/1` function, you must not also have a co-located `.heex`
  template file (and vice versa). Use one or the other.

**Implicit render:** If you do not define `render/1`, Phoenix looks for a co-located
template file at the same path as the module:

```text
lib/my_app_web/live/lesson2_lifecycle_live.ex
lib/my_app_web/live/lesson2_lifecycle_live.html.heex  <-- auto-discovered
```

---

### 5. `handle_event/3`

**Signature:** `handle_event(event_name, params, socket)`

`handle_event/3` is triggered by user interactions in the browser. The event name is a
string matching the `phx-*` attribute value in the template.

```elixir
# Template bindings that trigger handle_event:
# phx-click="increment"          -> handle_event("increment", params, socket)
# phx-submit="save"              -> handle_event("save", %{"form_field" => "value"}, socket)
# phx-change="validate"          -> handle_event("validate", %{"form_field" => "value"}, socket)
# phx-blur="field-blur"          -> handle_event("field-blur", %{"value" => "..."}, socket)
# phx-focus="field-focus"        -> handle_event("field-focus", %{"value" => "..."}, socket)
# phx-keydown="key-pressed"      -> handle_event("key-pressed", %{"key" => "Enter"}, socket)
# phx-window-keydown="global-key"-> handle_event("global-key", %{"key" => "Escape"}, socket)

def handle_event("increment", _params, socket) do
  {:noreply, assign(socket, count: socket.assigns.count + 1)}
end

def handle_event("save", %{"profile" => profile_params}, socket) do
  case Accounts.update_profile(socket.assigns.user, profile_params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> assign(user: user)
       |> put_flash(:info, "Profile updated")}

    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

**Return values:**

```elixir
# Most common — process the event, update state, no reply payload
{:noreply, socket}

# Reply with data to the client (used with JS hooks via pushEvent)
{:reply, %{status: "ok", id: 42}, socket}
```

The `params` map contains the event payload. For form events (`phx-submit`,
`phx-change`), it contains the form field values keyed by the form name. For click
events, it contains any `phx-value-*` attributes:

```heex
<button phx-click="delete" phx-value-id={item.id} phx-value-type="soft">
  Delete
</button>
<!-- params = %{"id" => "42", "type" => "soft"} -->
```

---

### 6. `handle_info/2`

**Signature:** `handle_info(message, socket)`

`handle_info/2` receives **Erlang/OTP messages** sent to the LiveView process. This is
the bridge between LiveView and the rest of the BEAM ecosystem. Any process that knows
the LiveView's PID can send it a message.

```elixir
# Receiving a PubSub broadcast
def handle_info(%{event: "new_message", payload: message}, socket) do
  {:noreply, stream_insert(socket, :messages, message)}
end

# Receiving a self-sent message (common pattern for deferring work)
def handle_info(:tick, socket) do
  {:noreply, assign(socket, time: DateTime.utc_now())}
end

# Receiving a message from a Task
def handle_info({ref, result}, socket) when is_reference(ref) do
  Process.demonitor(ref, [:flush])
  {:noreply, assign(socket, result: result)}
end

# Receiving a DOWN message (task finished or crashed)
def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
  {:noreply, socket}
end
```

**Common sources of messages:**

| Source | How it sends | Example |
|---|---|---|
| PubSub | `Phoenix.PubSub.broadcast/3` | Real-time updates from other users |
| `send/2` | `send(self(), :tick)` | Deferring work from mount or handle_event |
| `:timer` | `:timer.send_interval/2` | Periodic updates (clocks, polling) |
| `Task` | `Task.async/1` | Background computation results |
| GenServer | `GenServer.cast/2` or `send/2` | Messages from other OTP processes |

`handle_info/2` is what makes LiveView a first-class OTP citizen. Your LiveView can
participate in the same message-passing patterns as any other Erlang process.

---

### 7. `terminate/2`

**Signature:** `terminate(reason, socket)`

`terminate/2` is called when the LiveView process shuts down. This happens when the user
closes the browser tab, navigates away, or the process is stopped by its supervisor.

```elixir
def terminate(reason, socket) do
  # Best-effort cleanup
  IO.inspect(reason, label: "LiveView terminating")

  # Example: notify other users that this user left
  if user = socket.assigns[:user] do
    Phoenix.PubSub.broadcast(MyApp.PubSub, "presence", {:user_left, user.id})
  end

  :ok
end
```

**Critical caveat:** `terminate/2` is **not guaranteed to run.** It will not be called if:

- The process crashes (an unhandled exception kills the process before `terminate` runs)
- The network drops suddenly (the server does not know the client is gone until a
  heartbeat timeout, and even then, `terminate` may not run depending on how the process
  exits)
- The BEAM node shuts down abruptly (power loss, `kill -9`)

**Do not rely on `terminate/2` for critical cleanup.** If you need guaranteed cleanup
(releasing a database lock, sending a critical notification), use a separate supervised
process, a database transaction, or `Phoenix.Presence` (which detects disconnects via
heartbeat and runs cleanup independently).

---

## Common Pitfalls

1. **Expensive work in the disconnected mount** — Database queries, API calls, and
   subscriptions in `mount/3` without a `connected?(socket)` guard run twice and waste
   resources. The disconnected mount process terminates immediately after producing HTML.
   Guard expensive operations:
   ```elixir
   if connected?(socket) do
     # expensive work here
   end
   ```

2. **Forgetting that `handle_params/3` fires after `mount/3`** — If you set initial
   state in `mount/3` that depends on query parameters, it will be immediately overwritten
   by `handle_params/3`. Put URL-dependent state in `handle_params/3` only, or be aware
   of the ordering:
   ```elixir
   # mount sets defaults, handle_params overrides with URL state
   def mount(_, _, socket), do: {:ok, assign(socket, tab: "details")}
   def handle_params(%{"tab" => tab}, _, socket), do: {:noreply, assign(socket, tab: tab)}
   def handle_params(_, _, socket), do: {:noreply, socket}  # no tab param, keep default
   ```

3. **Catch-all `handle_info` silently swallowing messages** — A catch-all clause at the
   bottom of your module will silently drop unexpected messages, making bugs invisible:
   ```elixir
   # Dangerous — hides bugs
   def handle_info(_msg, socket), do: {:noreply, socket}

   # Better — log unexpected messages so you notice them
   def handle_info(msg, socket) do
     require Logger
     Logger.warning("Unexpected message in #{__MODULE__}: #{inspect(msg)}")
     {:noreply, socket}
   end
   ```

4. **Relying on `terminate/2` for critical cleanup** — `terminate` is best-effort only.
   Use Phoenix.Presence, supervised processes, or database-level mechanisms for
   guaranteed cleanup.

5. **Putting side effects in `render/1`** — `render/1` should be a pure function. Never
   call `send/2`, write to the database, or trigger external actions from `render/1`.
   These belong in `handle_event/3` or `handle_info/2`.

6. **Confusing `live_patch` and `navigate`** — `live_patch` stays in the same process
   and triggers `handle_params`. `navigate` starts a new process (new `mount` +
   `handle_params`). Using the wrong one leads to either unexpected state retention or
   unnecessary remounts.

---

## Exercises

1. Create a LiveView that logs every lifecycle callback to the console
   (`IO.puts("mount called")`, etc.). Load the page and observe the sequence. Confirm
   that `mount` runs before `handle_params`, and that both run twice (disconnected +
   connected).
2. Build a tabbed interface using `handle_params/3` and `live_patch`. The URL should
   change when switching tabs (e.g., `?tab=settings`), and refreshing the page should
   restore the correct tab.
3. Set up a `:timer.send_interval(1000, self(), :tick)` in the connected mount. Handle
   the `:tick` message in `handle_info/2` and display a live clock that updates every
   second.
4. Add a `terminate/2` callback that logs when the process shuts down. Close the browser
   tab and observe whether `terminate` fires (it may or may not, depending on timing).
5. Create a `handle_event/3` that uses `send(self(), {:deferred_work, data})` to defer
   expensive processing to `handle_info/2`, keeping the event handler responsive.
