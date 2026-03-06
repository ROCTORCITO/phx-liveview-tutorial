# Lesson 8: Streams & Async

## Overview

Streams and async assigns are two of the most important performance primitives in
Phoenix LiveView. Together they solve the two biggest bottlenecks in server-rendered
real-time UIs: **memory** and **latency**.

Every LiveView connection runs as a separate Erlang/BEAM process with its own memory.
If you store a list of 10,000 items in a regular assign, each connected user holds
their own copy. With 500 users, that's 500 copies. Streams solve this by sending items
to the client and then discarding them from server memory.

**Source file:** `lib/liveview_lab_web/live/lesson8_streams_live.ex`

---

## Core Concepts

### 1. Streams (`stream/3`)

Streams are LiveView's mechanism for rendering large collections **without keeping
them in server memory**. When you use `stream/3`, the items are sent to the client
once and then forgotten by the server.

```elixir
# In mount/3
socket
|> stream(:messages, [])           # Initialize empty stream
|> stream(:messages, initial_list) # Or with initial data

# In handle_event/3 or handle_info/2:

# Adding items
stream_insert(socket, :messages, new_message)

# Removing items
stream_delete(socket, :messages, %{id: msg_id})

# Batch append
stream(socket, :messages, list_of_items)

# Reset (clear all and repopulate)
stream(socket, :messages, new_items, reset: true)
```

**In the template:**
```heex
<div id="messages" phx-update="stream">
  <div :for={{dom_id, msg} <- @streams.messages} id={dom_id}>
    {msg.body}
  </div>
</div>
```

Key rules:
- Container must have `phx-update="stream"` and a unique `id`
- Each child must have `id={dom_id}` from the stream tuple
- Items need an `:id` field (integer or string) — streams use this to generate
  unique DOM element IDs for tracking, diffing, and targeted updates. You can
  customize this with the `:dom_id` option in `stream/3` if your struct uses a
  different key.
- Access via `@streams.messages`, not `@messages`
- Without `phx-update="stream"`, the template will error because `@streams.messages`
  yields `{dom_id, item}` tuples, not plain items

### How Streams Work Internally

1. Server sends items with a `stream_insert` instruction
2. LiveView's client-side DOM patching engine diffs the current DOM against the new
   content and applies minimal DOM node updates (inserting, removing, or replacing elements)
3. Server immediately discards the item data — it only keeps a lightweight manifest
   of DOM IDs so it can issue insert/delete/reorder commands later
4. On reconnect, `mount` runs again and re-streams initial data because the server
   discarded the items and must rebuild from the source

**Memory impact:** A chat with 10,000 messages uses the same server memory for the
message collection as one with 10 messages. The items only exist in the browser DOM.
(The server still uses memory for the socket, assigns, and stream metadata, but not
for the items themselves.)

---

### 2. Async Assigns (`assign_async/3`)

`assign_async` spawns a monitored task to load data without blocking the initial
render. The LiveView renders immediately with a `:loading` state, then automatically
updates when the data arrives. You do not write a `handle_async` callback for this —
the result is handled for you and stored in the assign.

```elixir
# In mount/3
assign_async(socket, :user_profile, fn ->
  {:ok, %{user_profile: Accounts.get_profile(user_id)}}
end)
```

The callback function **must** return `{:ok, %{key => value}}` where the key matches
the assign name, or `{:error, reason}` on failure.

**In the template:**
```heex
<.async_result :let={profile} assign={@user_profile}>
  <:loading>Loading...</:loading>
  <:failed :let={reason}>Error: {inspect(reason)}</:failed>
  Welcome, {profile.name}!
</.async_result>
```

The async result (`Phoenix.LiveView.AsyncResult`) goes through states:
- `%AsyncResult{ok?: false, loading: initial_data}` — task running
- `%AsyncResult{ok?: true, result: data}` — task completed
- `%AsyncResult{ok?: false, failed: reason}` — task failed

**Re-triggering:** Call `assign_async` again to re-fetch:
```elixir
def handle_event("refresh", _, socket) do
  {:noreply, assign_async(socket, :data, fn ->
    {:ok, %{data: fetch_fresh_data()}}
  end)}
end
```

> **`assign_async` vs `start_async`:** `assign_async` automatically stores the result
> in the named assign. `start_async` is a lower-level alternative where you handle the
> result yourself in a `handle_async/3` callback. Both are for **one-shot** operations
> that return a single result — neither is designed for streaming multiple messages.

---

### 3. Combining Streams + Async

A common pattern: use `start_async` for the initial data fetch, then populate the
stream when it completes. For real-time updates, use `stream_insert` as new items
arrive via PubSub (Phoenix's built-in publish/subscribe system for broadcasting
messages between processes).

```elixir
def mount(_, _, socket) do
  socket =
    socket
    |> stream(:items, [])
    |> start_async(:initial_load, fn ->
      Repo.all(Item)
    end)

  {:ok, socket}
end

# handle_async is the callback for start_async (not assign_async)
def handle_async(:initial_load, {:ok, items}, socket) do
  {:noreply, stream(socket, :items, items)}
end

def handle_async(:initial_load, {:exit, reason}, socket) do
  {:noreply, put_flash(socket, :error, "Failed to load: #{inspect(reason)}")}
end
```

---

### 4. Chunked Stream Loading

When you have thousands of items to stream, inserting them all at once bundles a
massive HTML payload into a single WebSocket frame. The browser's JavaScript engine
locks up while rendering the DOM, making the UI unresponsive.

**The fix:** break the dataset into small chunks and send them in waves, giving the
browser a "breath" between each batch.

```elixir
@chunk_size 50

def handle_event("load_large_dataset", _params, socket) do
  items = generate_items(5000)

  {chunk, rest} = Enum.split(items, @chunk_size)

  socket =
    socket
    |> stream(:items, chunk)
    |> assign(pending_items: rest)

  # Schedule the next chunk — the 0ms delay yields control back to the
  # process mailbox so it can handle UI events between chunks
  if rest != [] do
    send(self(), :load_next_chunk)
  end

  {:noreply, socket}
end

def handle_info(:load_next_chunk, socket) do
  {chunk, rest} = Enum.split(socket.assigns.pending_items, @chunk_size)

  socket =
    socket
    |> stream(:items, chunk)
    |> assign(pending_items: rest)

  if rest != [] do
    send(self(), :load_next_chunk)
  end

  {:noreply, socket}
end
```

**How it works:**
1. Split items into a chunk of N and the remaining items
2. Stream-insert the first chunk (browser renders ~50 DOM nodes)
3. `send(self(), :load_next_chunk)` puts a message in the process mailbox —
   this yields control so any pending UI events (scrolls, clicks) get processed first
4. `handle_info` picks up the next chunk and repeats until done

**Why `send/2` instead of `Process.send_after/3`?** Plain `send` with a 0ms delay is
usually enough — the key is yielding the process mailbox, not adding wall-clock delay.
Use `Process.send_after(self(), :load_next_chunk, 50)` if you want a visible pause
between waves (e.g., for a staggered animation effect).

**Chunk size tuning:** 50–100 items is a good starting point. Smaller chunks keep the
UI more responsive but increase the number of WebSocket frames. Profile with your
actual item templates — complex markup may need smaller chunks.

---

## When to Use What

| Scenario | Use | Why |
|---|---|---|
| List of 100+ items | `stream/3` | Server discards items after sending, keeping memory constant |
| Initial data that's slow to load | `assign_async/3` | Non-blocking — UI renders immediately with loading state |
| Data you need to filter/sort on server | Regular `assign` | Server must hold the data to filter/sort it; streams discard items so you'd have to reset the entire stream |
| Real-time feed (chat, logs) | `stream/3` + PubSub | Efficient appending without growing server memory |
| One-time expensive computation | `assign_async/3` | Avoids blocking mount while the computation runs |
| Streaming 1,000+ items at once | Chunked stream loading | Keeps UI responsive by sending items in waves via `send/2` |

---

## Common Pitfalls

1. **Forgetting `phx-update="stream"`** — the template will error because `@streams.messages` yields `{dom_id, item}` tuples
2. **Missing `:id` on items** — streams require unique IDs for DOM element tracking and diffing
3. **Trying to access stream items on server** — they don't exist there after being sent to the client
4. **Not handling async failures** — always provide a `<:failed>` slot
5. **Blocking mount with slow queries** — use `assign_async` instead
6. **Streaming thousands of items at once** — freezes the browser; use chunked loading instead

---

## Exercises

1. Add a "filter" input that resets the stream and re-populates with filtered items
2. Implement `stream_insert` with `at: 0` to prepend items instead of appending
3. Create a `start_async` task that loads data, and add a "cancel" button that calls `cancel_async(socket, :task_name)` to abort it
4. Build a "live search" that uses assign_async with debounce
5. Modify the chunked loader to show a progress bar (track `chunked_loaded` / `chunked_total` assigns)
6. Try changing the chunk size from 50 to 500 — observe how it affects UI responsiveness during loading
