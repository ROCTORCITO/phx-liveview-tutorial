# Lesson 10: Temporary Assigns & Pagination

## Overview

This lesson covers memory management strategies in LiveView, with focus on how
streams replaced the older `temporary_assigns` pattern, and how to implement
efficient pagination.

**Source file:** `lib/liveview_lab_web/live/lesson10_temp_assigns_live.ex`

---

## The Memory Problem

Every LiveView connection runs as a separate Erlang/BEAM process with its own memory
space. Assigns are per-process state. If you store a list of 10,000 items in a regular
assign, each connected user holds their own copy:

```elixir
# BAD: 10,000 items in process memory, full diff on every change
assign(socket, items: Repo.all(Item))
```

1,000 users x 10,000 items = 1,000 separate copies in memory.

---

## Solution 1: temporary_assigns (Legacy)

> **Note:** `phx-update="append"` and `phx-update="prepend"` are deprecated in
> Phoenix LiveView 1.0+. Use streams instead. The `temporary_assigns` option itself
> still exists (for non-collection use cases like flash-like data), but for lists
> you should always use streams. This section is for understanding existing codebases.

```elixir
# mount/3 returns a three-element tuple; the third element is an options keyword list
# that declares which assigns should be cleared after each render.
def mount(_, _, socket) do
  {:ok, assign(socket, items: fetch_items()), temporary_assigns: [items: []]}
end
```

After each render:
1. `@items` is sent to the client
2. Server resets `@items` to `[]` (the default specified above)
3. Client keeps the DOM — elements persist in the browser

Required `phx-update="append"` on the container:
```heex
<div id="items" phx-update="append">
  <div :for={item <- @items} id={"item-#{item.id}"}>{item.name}</div>
</div>
```

**Limitations** (these exist because the server discards the data after render, so it
has no knowledge of what the client is displaying):
- Append-only (no delete, no reorder)
- No way to reset/clear from server
- `phx-update="append"` is a footgun — easy to get wrong

---

## Solution 2: Streams (Modern)

Streams solve all the problems of temporary_assigns. They work by maintaining a
lightweight server-side manifest of DOM IDs (without item data), which enables
insert/delete/reorder operations without holding any collection data in server memory.

```elixir
def mount(_, _, socket) do
  {:ok, stream(socket, :items, fetch_items())}
end
```

```heex
<div id="items" phx-update="stream">
  <div :for={{dom_id, item} <- @streams.items} id={dom_id}>
    {item.name}
  </div>
</div>
```

### Stream Operations

```elixir
# Append items
stream(socket, :items, new_items)

# Prepend a single item
stream_insert(socket, :items, item, at: 0)

# Append a single item (default)
stream_insert(socket, :items, item)

# Delete an item
stream_delete(socket, :items, item)
# or by constructing a struct with just the id:
stream_delete(socket, :items, %{id: item_id})

# Replace/update an item (same id = replace)
stream_insert(socket, :items, updated_item)

# Reset entire stream
stream(socket, :items, new_items, reset: true)

# Clear everything
stream(socket, :items, [], reset: true)
```

### Stream Append Pattern

Initialize empty streams and append items on demand — track a counter to show the
user how many items exist without keeping the items in server memory:

```elixir
def mount(_, _, socket) do
  socket =
    socket
    |> stream(:append_items, [])
    |> assign(append_count: 0)

  {:ok, socket}
end

def handle_event("add_items", _params, socket) do
  count = socket.assigns.append_count
  new_items = for i <- (count + 1)..(count + 10), do: %{id: i, text: "Item #{i}"}

  socket =
    socket
    |> stream(:append_items, new_items)
    |> assign(append_count: count + 10)

  {:noreply, socket}
end
```

### Why Streams Win

| Feature | temporary_assigns | Streams |
|---|---|---|
| Server memory (collection) | Cleared after render | Never stored |
| Append items | Yes | Yes |
| Prepend items | No | Yes (`at: 0`) |
| Delete items | No | Yes |
| Update items | No | Yes (re-insert) |
| Reset/clear | No | Yes (`reset: true`) |
| Reorder | No | Yes |

> Both approaches briefly hold item data in process memory during the render cycle
> (for serializing to the wire). The key difference is that streams never store item
> data between renders — the server only keeps a manifest of DOM IDs.

---

## Stream-Based Pagination

### Load More Pattern

```elixir
@page_size 20

def mount(_, _, socket) do
  socket =
    socket
    |> assign(page: 1, end_of_data: false, loading: false)
    |> stream(:items, fetch_page(1))

  {:ok, socket}
end

def handle_event("load_more", _, socket) do
  page = socket.assigns.page + 1
  items = fetch_page(page)

  socket =
    socket
    |> stream(:items, items)
    |> assign(page: page, end_of_data: length(items) < @page_size)

  {:noreply, socket}
end
```

**Simulating async loading:** The source uses `send(self(), :do_load_more)` to defer
the actual data fetch to `handle_info`, showing a loading state immediately:

```elixir
def handle_event("load_more", _params, socket) do
  send(self(), :do_load_more)
  {:noreply, assign(socket, loading: true)}
end

def handle_info(:do_load_more, socket) do
  page = socket.assigns.page + 1
  items = generate_items_for_page(page)
  end_of_data = page >= 5  # Hardcoded limit for demo

  socket =
    socket
    |> stream(:items, items)
    |> assign(page: page, end_of_data: end_of_data, loading: false)

  {:noreply, socket}
end

defp fetch_page(page) do
  Item
  |> order_by(desc: :inserted_at)
  |> limit(@page_size)
  # The ^ (pin operator) injects the Elixir expression into the Ecto query
  # rather than referencing an Ecto binding variable.
  |> offset(^((page - 1) * @page_size))
  |> Repo.all()
end
```

### Infinite Scroll with Viewport Hook

```heex
<div id="items" phx-update="stream">
  <div :for={{dom_id, item} <- @streams.items} id={dom_id}>
    {item.name}
  </div>
</div>

<div
  :if={not @end_of_data}
  id="infinite-scroll-marker"
  phx-hook="InfiniteScroll"
  data-page={@page}
/>
```

The `phx-hook` attribute connects a DOM element to a JavaScript Hook object. Hooks
are registered when creating the LiveSocket in `app.js` (see Lesson 6 for details).
The hook below uses `IntersectionObserver`, a browser API that fires a callback when
an element becomes visible in the viewport:

```javascript
// In assets/js/app.js, add to your Hooks object:
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver((entries) => {
      const entry = entries[0]
      if (entry.isIntersecting) {
        this.pushEvent("load_more", {})
      }
    })
    this.observer.observe(this.el)
  },
  destroyed() {
    this.observer.disconnect()
  }
}
```

### Cursor-Based Pagination (Better for Real Apps)

Offset pagination (`OFFSET 1000`) requires the database to scan and skip all 1,000
rows before returning results — queries get progressively slower as the offset grows.
Cursor-based pagination uses an indexed `WHERE` clause instead, which is O(log n)
regardless of position:

```elixir
# First page — no cursor
defp fetch_page(nil) do
  Item |> order_by(desc: :id) |> limit(@page_size) |> Repo.all()
end

# Subsequent pages — use the last item's ID as cursor
defp fetch_page(cursor) do
  Item
  |> where([i], i.id < ^cursor)
  |> order_by(desc: :id)
  |> limit(@page_size)
  |> Repo.all()
end

# In handle_event:
def handle_event("load_more", _, socket) do
  items = fetch_page(socket.assigns.cursor)

  # Guard against empty results (happens on the last page)
  cursor = if items != [], do: List.last(items).id, else: socket.assigns.cursor

  socket =
    socket
    |> stream(:items, items)
    |> assign(cursor: cursor, end_of_data: length(items) < @page_size)

  {:noreply, socket}
end
```

---

## Bidirectional Scrolling

For chat-like UIs where you scroll up to load older messages:

```elixir
def mount(_, _, socket) do
  messages = fetch_recent_messages(50)

  # Guard against no messages
  oldest_id = case messages do
    [] -> nil
    [first | _] -> first.id
  end

  socket =
    socket
    |> stream(:messages, messages)
    |> assign(oldest_id: oldest_id)

  {:ok, socket}
end

def handle_event("load_older", _, socket) do
  older = fetch_before(socket.assigns.oldest_id, 20)

  # Important: stream/4 with `at: 0` inserts items one by one at position 0,
  # which reverses the batch order. If `older` is [msg1, msg2, msg3] sorted
  # oldest-first, the DOM would show msg3, msg2, msg1. Reverse first:
  socket =
    socket
    |> stream(:messages, Enum.reverse(older), at: 0)
    |> assign(oldest_id: if(older != [], do: List.first(older).id, else: socket.assigns.oldest_id))

  {:noreply, socket}
end
```

---

## Performance Checklist

- [ ] Large lists should use streams (saves server memory proportional to list size)
- [ ] Never load unbounded data (`Repo.all` without limit)
- [ ] Use cursor-based pagination for large datasets (avoids slow OFFSET queries)
- [ ] Consider `assign_async` for initial page load
- [ ] Cap real-time streams (e.g., keep last 500 log lines)

---

## Exercises

1. Implement cursor-based pagination with a database-backed stream
2. Build bidirectional scrolling (load older on scroll up, newer on scroll down)
3. Add a "jump to top" button that resets the stream to the first page
4. Implement virtual scrolling (only render visible items) using a JS hook
