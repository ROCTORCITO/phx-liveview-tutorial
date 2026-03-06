# Lesson 1: LiveView Architecture

## Overview

Phoenix LiveView is a framework for building **server-rendered real-time user interfaces**
over WebSockets. Unlike single-page application (SPA) frameworks such as React, Vue, or
Angular, LiveView requires no client-side JavaScript framework, no client-side routing,
no JSON API layer, and no separate state management library. The server holds all state,
renders HTML, and pushes only the parts that changed to the browser over a persistent
WebSocket connection.

The result is a development model where you write Elixir on the server and get real-time,
interactive UIs without building or maintaining a JavaScript frontend.

**Source file:** `lib/liveview_lab_web/live/lesson1_architecture_live.ex`

---

## Core Concepts

### 1. What LiveView Is

LiveView is a server-side rendering framework with real-time capabilities. Every
interaction — clicking a button, submitting a form, typing into a search box — sends a
small event over a WebSocket to the server. The server processes the event, updates its
state, re-renders the affected parts of the template, and sends a compact diff back to
the browser. The client-side JavaScript library (included automatically) patches the DOM.

```elixir
defmodule MyAppWeb.CounterLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Count: {@count}</h1>
      <button phx-click="increment">+1</button>
    </div>
    """
  end
end
```

In this example, clicking the button sends a `"increment"` event to the server. The
server increments the count, re-renders only the `{@count}` expression, and sends a tiny
JSON diff to update the DOM. No full page reload. No JavaScript state. No API endpoint.

---

### 2. How LiveView Differs from SPAs

| Concern | SPA (React, Vue, etc.) | Phoenix LiveView |
|---|---|---|
| Routing | Client-side router (React Router, Vue Router) | Server-side router (`Phoenix.Router`) |
| State management | Redux, Zustand, Pinia, signals, etc. | Server-side assigns on the socket |
| API layer | REST or GraphQL endpoints | None — events go directly to the LiveView process |
| Initial load | Blank HTML + JS bundle, then client renders | Full HTML on first paint (SEO-friendly) |
| Real-time updates | WebSocket library + custom protocol | Built-in over the same WebSocket |
| Bundle size | Grows with dependencies | Fixed ~30 KB JS (LiveView client library) |

LiveView eliminates entire categories of frontend complexity: serialization formats,
API versioning, CORS, token management for API auth, client-side caching, and hydration
mismatches. The tradeoff is a persistent connection to the server and a network roundtrip
for every interaction (typically 1-10ms on the same data center, 20-80ms over the
internet).

---

### 3. The BEAM Process Model

Every LiveView connection runs inside its own **Erlang/BEAM process**. These are not
operating system processes or threads — they are lightweight, isolated units of execution
managed by the BEAM virtual machine.

Key characteristics:

- **Lightweight:** Each process uses approximately 2 KB of initial memory, compared to
  megabytes for an OS thread. The BEAM can run millions of concurrent processes on a
  single machine.
- **Isolated:** Processes share nothing. A crash in one LiveView process cannot corrupt
  another. If a user's connection crashes, only that user is affected.
- **Supervised:** Processes are organized under supervision trees. When a LiveView process
  crashes, its supervisor can restart it cleanly. The user sees a brief reconnection and
  the LiveView re-mounts with fresh state.
- **Preemptively scheduled:** The BEAM scheduler ensures no single process can starve
  others. Even if one LiveView runs an expensive computation, other connections continue
  to be served.

```text
Application Supervisor
  |
  +-- Endpoint (Cowboy/Bandit HTTP server)
  |     |
  |     +-- WebSocket connection for User A -> LiveView process (PID #0.456.0)
  |     +-- WebSocket connection for User B -> LiveView process (PID #0.457.0)
  |     +-- WebSocket connection for User C -> LiveView process (PID #0.458.0)
  |     +-- ... (millions more)
  |
  +-- PubSub Supervisor
  +-- Repo (Ecto database pool)
```

This model is why LiveView can handle tens of thousands of concurrent connections on a
single server without special tuning — each connection is just another lightweight process.

---

### 4. The Request Flow

A LiveView page load goes through a well-defined sequence of steps:

```text
Browser                          Server
  |                                |
  |--- HTTP GET /counter --------->|
  |                                |-- Router matches route
  |                                |-- Endpoint pipeline (plugs: CSP, session, etc.)
  |                                |-- LiveView mount (disconnected)
  |                                |-- Full HTML rendered
  |<-- Complete HTML page ---------|
  |                                |
  | (browser renders HTML,         |
  |  LiveView JS initializes)      |
  |                                |
  |--- WebSocket upgrade --------->|
  |                                |-- LiveView mount (connected)
  |<-- WebSocket established ------|
  |                                |
  | (real-time interaction begins) |
  |                                |
  |--- phx-click "increment" ----->|
  |                                |-- handle_event("increment", ...)
  |                                |-- Re-render, compute diff
  |<-- JSON diff: {count: 1} ------|
  |                                |
  | (client patches DOM)           |
```

Step by step:

1. **HTTP GET** — The browser makes a standard HTTP request.
2. **Router** — `Phoenix.Router` matches the path to a LiveView module.
3. **Endpoint pipeline** — The request passes through Plug middleware (session, CSRF,
   content security policy, etc.).
4. **Disconnected mount** — The LiveView's `mount/3` callback runs. At this point,
   `connected?(socket)` returns `false`. The server renders full HTML.
5. **HTML response** — The browser receives a complete HTML page. The user sees content
   immediately (good for SEO and perceived performance).
6. **WebSocket upgrade** — The LiveView JavaScript client opens a WebSocket connection.
7. **Connected mount** — `mount/3` runs again in a new process. Now
   `connected?(socket)` returns `true`. This is where you start timers, subscribe to
   PubSub topics, and kick off async data loads.
8. **Interactive** — Events flow over the WebSocket. The server sends diffs.

---

### 5. Two-Phase Mount

The `mount/3` callback is called **twice** for every page load: once during the
disconnected (HTTP) phase and once during the connected (WebSocket) phase. This is not
a bug — it is a deliberate design decision.

```elixir
def mount(_params, _session, socket) do
  # This code runs TWICE:
  # 1. Disconnected mount: for the initial HTML response
  # 2. Connected mount: when the WebSocket connects

  # Always set default assigns (runs both times)
  socket = assign(socket, count: 0, status: "ready")

  # Only do expensive/side-effectful work when connected
  socket =
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(MyApp.PubSub, "counter:updates")

      # Start a periodic timer
      :timer.send_interval(1000, self(), :tick)

      # Kick off an async data load
      assign_async(socket, :history, fn ->
        {:ok, %{history: Repo.all(CounterEvent)}}
      end)
    else
      socket
    end

  {:ok, socket}
end
```

**Why two phases?**

| Phase | `connected?(socket)` | Purpose |
|---|---|---|
| Disconnected | `false` | Render static HTML fast. Search engines and screen readers see real content. Users see a meaningful page before the WebSocket connects. |
| Connected | `true` | Start real-time features: PubSub subscriptions, timers, async loads. These only make sense when there is a live connection. |

If you subscribe to PubSub in the disconnected phase, the subscription is wasted (that
process terminates after sending the HTML). If you run an expensive database query in the
disconnected phase, you run it twice — once for the throwaway HTML and once for the real
connection. Guard expensive work behind `connected?(socket)`.

---

### 6. Server-Rendered Diffs

After the first full HTML render, LiveView never sends a complete page again. Instead,
it sends **compact JSON diffs** — small payloads describing only what changed.

Consider this template:

```heex
<div>
  <h1>Welcome to the Dashboard</h1>
  <p>Your score: {@score}</p>
  <p>Last updated: {@updated_at}</p>
  <footer>Copyright 2025 MyApp</footer>
</div>
```

On the first render, the server sends the entire HTML. On subsequent renders (say, when
`@score` changes from 42 to 43), the server sends something like:

```json
{"0": "43"}
```

That is the entire payload — a JSON object mapping a slot index to the new value. The
client-side library knows which part of the DOM corresponds to slot `"0"` and patches
just that text node. The `<h1>`, `<footer>`, and unchanged `<p>` are never re-sent.

This is why LiveView feels fast even over slower connections. A typical diff is 50-200
bytes, far smaller than a full API response.

---

### 7. Change Tracking

LiveView's change tracking is the mechanism that makes diffs so small. It works at the
**assign level**, not the template level.

Here is what happens when you call `assign(socket, score: 43)`:

1. LiveView records that the `:score` assign changed.
2. At render time, LiveView walks the template and **only re-evaluates expressions that
   reference `:score`**.
3. Expressions referencing unchanged assigns (like `@updated_at`) are skipped entirely —
   their previous output is reused.
4. The diff contains only the new output of the changed expressions.

```elixir
# Only @score changed, so only "{@score}" is re-evaluated.
# "{@updated_at}" is skipped — its previous value is reused in the diff.

def handle_event("add_point", _params, socket) do
  {:noreply, assign(socket, score: socket.assigns.score + 1)}
  # @updated_at did not change, so its template expression is not re-evaluated
end
```

This is automatic. There is no equivalent of React's `shouldComponentUpdate`,
`useMemo`, or `React.memo`. LiveView's compiler instruments the `~H` sigil at compile
time to track which assigns each expression depends on.

**Structuring templates for change tracking:** If you have a large static block of HTML,
make sure it does not reference a volatile assign. If it does, the entire expression must
be re-evaluated on every change. Break large templates into smaller function components
to keep change tracking granular.

---

### 8. The Socket Struct

The `socket` in LiveView is **not a network socket**. It is a data structure —
`%Phoenix.LiveView.Socket{}` — that holds all the state for a LiveView process.

```elixir
%Phoenix.LiveView.Socket{
  assigns: %{
    count: 0,
    flash: %{},
    live_action: :index
  },
  transport_pid: #PID<0.456.0>,
  endpoint: MyAppWeb.Endpoint,
  view: MyAppWeb.CounterLive,
  # ... other metadata
}
```

Key fields:

- **`assigns`** — A map of all your state. Accessed in templates as `@count`, `@user`,
  etc. Modified with `assign/2`, `assign/3`, `assign_new/3`.
- **`transport_pid`** — The PID of the WebSocket transport process. `nil` during the
  disconnected mount.
- **`endpoint`** — The Phoenix endpoint module (used for routing helpers, PubSub, etc.).
- **`view`** — The LiveView module currently being rendered.

You never modify the socket struct directly. Always use the provided functions:

```elixir
# Correct
socket = assign(socket, count: 42)

# Wrong — bypasses change tracking
socket = %{socket | assigns: Map.put(socket.assigns, :count, 42)}
```

Bypassing `assign/2` breaks change tracking. LiveView will not know that `:count`
changed and will not include it in the diff.

---

### 9. Common Misconceptions

**"LiveView re-renders the whole page on every interaction."**
No. LiveView sends only the parts of the template that changed. A button click that
increments a counter sends a diff of a few bytes, not a full HTML page.

**"Roundtrips to the server make it slow."**
Diffs are tiny (often under 200 bytes). On a typical connection, the roundtrip is
imperceptible. For sub-millisecond interactions (drag-and-drop, real-time drawing),
LiveView provides JS hooks and `phx-debounce` to handle latency.

**"Every user gets a copy of the data, so it doesn't scale."**
This is partially true — each process holds its own assigns. But this is the same
tradeoff as any stateful server. For large collections, use **streams** (`stream/3`)
which send items to the client and discard them from server memory. For shared data,
use ETS or a cache layer.

**"You can't do anything without JavaScript."**
LiveView includes a rich set of client-side bindings (`phx-click`, `phx-submit`,
`phx-change`, `phx-key`, transitions, etc.). For cases where you do need custom JS,
LiveView provides **JS hooks** — a well-defined interface for integrating JavaScript
while keeping the server as the source of truth.

---

### 10. Interactive Demos in the Source

The source file demonstrates these concepts with three interactive sections:

1. **Connection Inspector** — Displays `connected?(socket)`, transport mode, and `self()` PID.
   The PID changes between static render and WebSocket because they are different BEAM processes.

2. **Process Memory** — Uses `:erlang.process_info(self(), :memory)` to show how
   adding items to assigns grows the process heap:
   ```elixir
   defp get_memory do
     case :erlang.process_info(self(), :memory) do
       {:memory, bytes} -> bytes
       _ -> 0
     end
   end
   ```
   Click "Add 1,000 Items" repeatedly to watch memory climb — this is why streams
   exist for large lists.

3. **Diff Demo** — Shows the tiny JSON payload LiveView sends (`%{"0" => "5"}`) vs
   what a full page reload would require. Click the counter to see the contrast.

---

## Common Pitfalls

1. **Running expensive work in the disconnected mount** — The disconnected mount exists
   only to produce the initial HTML. Any database queries, API calls, or subscriptions
   run here are wasted because the process terminates immediately after. Guard them with
   `connected?(socket)`.
2. **Assuming mount runs once** — `mount/3` runs twice: once disconnected, once connected.
   Side effects like PubSub subscriptions must be in the connected phase, or they will be
   duplicated/lost.
3. **Bypassing assign/2** — Directly modifying `socket.assigns` breaks change tracking.
   Always use `assign/2` or `assign/3`.
4. **Sending too much data in assigns** — Each LiveView process holds its own copy of
   every assign. Storing a list of 50,000 records in an assign means each user holds
   50,000 records in memory. Use streams for large collections.
5. **Not understanding the diff model** — Writing templates that call expensive functions
   inline (e.g., `{Enum.count(large_list)}`) means that function runs on every render
   that touches that expression. Precompute values in event handlers and store them as
   assigns.

---

## Exercises

1. Add a `connected?(socket)` guard to a `mount/3` that subscribes to a PubSub topic.
   Verify that the subscription only happens once by inspecting the server logs.
2. Create a LiveView with two assigns: one that changes frequently (`@ticks`, updated
   by a timer) and one that is static (`@title`). Use browser DevTools to observe the
   WebSocket frames and confirm that only the changing assign is sent in diffs.
3. Build a LiveView that displays the current `socket.transport_pid` as a string.
   Observe that it is `nil` on disconnected mount and a real PID on connected mount.
4. Intentionally bypass `assign/2` by modifying `socket.assigns` directly and observe
   that the template does not update. Then fix it by using `assign/2`.
