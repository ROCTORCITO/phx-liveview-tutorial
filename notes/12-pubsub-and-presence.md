# Lesson 12: PubSub & Presence

## Overview

Phoenix.PubSub enables real-time communication between LiveView processes.
Combined with Phoenix.Presence, you can build collaborative features: shared
counters, live chat, typing indicators, cursor tracking, and more.

**Source file:** `lib/liveview_lab_web/live/lesson12_pubsub_live.ex`

---

## Core Concepts

### Phoenix.PubSub

PubSub is a topic-based, in-memory message distribution system built into Phoenix.
It is NOT a persistent message broker (like RabbitMQ or Kafka) — messages are not
queued or persisted. If no one is subscribed when a message is broadcast, it is lost.

PubSub works across nodes in an Erlang cluster via Erlang's `:pg` module (distributed
named process groups).

```
┌──────────┐   broadcast("room:1", msg)    ┌──────────┐
│ LiveView  │ ─────────────────────────────► │ PubSub   │
│ Process A │                                │ (:pg)    │
└──────────┘                                 └──┬───┬───┘
                                                │   │
                              ┌─────────────────┘   └──────────────────┐
                              ▼                                        ▼
                        ┌──────────┐                            ┌──────────┐
                        │ LiveView │                            │ LiveView │
                        │ Process B│                            │ Process C│
                        └──────────┘                            └──────────┘
```

### Three Operations

```elixir
# 1. Subscribe (in mount, only when connected)
#
# Why only when connected? LiveView mounts twice:
#   - First mount: for the static HTML render (disconnected). This process
#     may not persist, so subscribing here is wasteful.
#   - Second mount: when the WebSocket connects. This is the long-lived
#     process that should receive real-time messages.
if connected?(socket) do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "room:lobby")
end

# 2. Broadcast (send to ALL subscribers, including self)
Phoenix.PubSub.broadcast(MyApp.PubSub, "room:lobby", {:new_message, msg})

# 3. Receive (in handle_info)
def handle_info({:new_message, msg}, socket) do
  {:noreply, assign(socket, messages: [msg | socket.assigns.messages])}
end
```

---

## Pattern 1: Shared Counter

The simplest PubSub example — all tabs see the same counter.

```elixir
@topic "counter:global"

def mount(_, _, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, @topic)
  end

  # Note: New users joining will see count: 0 until the next increment.
  # For production, you'd fetch the current count from a persistent store
  # (e.g., ETS, database, or Agent) during mount to sync initial state.
  {:ok, assign(socket, count: 0)}
end

def handle_event("increment", _, socket) do
  Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, :increment)
  {:noreply, socket}
end

def handle_info(:increment, socket) do
  {:noreply, assign(socket, count: socket.assigns.count + 1)}
end
```

**Note:** The broadcaster also receives the message (it's subscribed too).
This keeps state consistent without special-casing the sender. The alternative
is using `broadcast_from` + local update (see below), which feels more responsive
but risks state divergence if the local update logic differs from the broadcast
handler.

---

## Pattern 2: Live Chat Room

```elixir
def handle_event("send_message", %{"body" => body}, socket) do
  msg = %{
    # unique_integer is unique within this runtime instance, but NOT
    # globally unique across a cluster. For distributed systems, use
    # a UUID instead: Ecto.UUID.generate()
    id: System.unique_integer([:positive]),
    user_id: socket.assigns.user_id,
    body: body,
    sent_at: DateTime.utc_now()
  }

  Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, {:new_message, msg})
  {:noreply, socket}
end

def handle_info({:new_message, msg}, socket) do
  # stream_insert sends the item to the client and discards it from server
  # memory. See Lesson 1 for how streams work.
  {:noreply, stream_insert(socket, :messages, msg)}
end
```

Using streams for chat messages = O(1) server memory for the message collection
per user.

---

## Pattern 3: User Presence

### Simple Presence (Manual Tracking)

```elixir
@topic "room:lobby"

def mount(_, _, socket) do
  user_id = Ecto.UUID.generate()

  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, @topic)
    Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, {:user_joined, %{user_id: user_id}})
  end

  {:ok, assign(socket, user_id: user_id, online_users: [])}
end

def handle_info({:user_joined, %{user_id: uid}}, socket) do
  {:noreply, assign(socket, online_users: [uid | socket.assigns.online_users])}
end

def handle_info({:user_left, %{user_id: uid}}, socket) do
  {:noreply, assign(socket, online_users: List.delete(socket.assigns.online_users, uid))}
end

def terminate(_reason, socket) do
  Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, {:user_left, %{user_id: socket.assigns.user_id}})
end
```

**Caveat:** `terminate/2` is not guaranteed to be called (process crash, node
failure). For reliable presence, use Phoenix.Presence.

### Phoenix.Presence (Production)

```elixir
# Define a Presence module
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,          # Used for configuration lookup
    pubsub_server: MyApp.PubSub  # Which PubSub to use for broadcasting diffs
end
```

```elixir
# In LiveView mount
def mount(_, _, socket) do
  if connected?(socket) do
    {:ok, _} = MyAppWeb.Presence.track(self(), @topic, socket.assigns.user_id, %{
      joined_at: DateTime.utc_now(),
      username: socket.assigns.username
    })

    Phoenix.PubSub.subscribe(MyApp.PubSub, @topic)
  end

  # Fetch initial presence list. During the disconnected (static) render,
  # this returns the current state but real-time updates only start after
  # the WebSocket connects.
  presences = MyAppWeb.Presence.list(@topic)
  {:ok, assign(socket, presences: presences)}
end

# Presence broadcasts diffs as plain maps over PubSub.
# The simplest approach: re-fetch the full presence list on each diff.
def handle_info(%{event: "presence_diff"}, socket) do
  presences = MyAppWeb.Presence.list(@topic)
  {:noreply, assign(socket, presences: presences)}
end
```

**Phoenix.Presence advantages:**
- Handles crashes/disconnects automatically (heartbeat-based)
- Works across cluster nodes
- Uses CRDTs (Conflict-free Replicated Data Types) under the hood — these are
  data structures that can be merged across nodes without conflicts, even during
  network partitions. This means presence data is eventually consistent without
  requiring coordination.

---

## Topic Design

Topics are just strings. Design them hierarchically:

```
"chat:lobby"          — Global chat room
"chat:room:42"        — Specific room
"user:123:activity"   — User-specific events
"game:abc:moves"      — Game-specific events
"admin:notifications" — Admin broadcast channel
```

### Scoped Subscriptions

```elixir
# User subscribes only to their rooms
for room_id <- user.room_ids do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "chat:room:#{room_id}")
end
```

---

## broadcast vs broadcast_from

```elixir
# broadcast — sends to ALL subscribers (including self)
Phoenix.PubSub.broadcast(MyApp.PubSub, topic, msg)

# broadcast_from — sends to all EXCEPT the sender
Phoenix.PubSub.broadcast_from(MyApp.PubSub, self(), topic, msg)
```

Use `broadcast_from` when the sender already applied the change locally
(optimistic update). This feels snappier because the user sees their action
immediately without waiting for the broadcast round-trip:

```elixir
def handle_event("increment", _, socket) do
  # Apply locally first (optimistic update)
  socket = assign(socket, count: socket.assigns.count + 1)
  # Then tell others (skip self since we already updated)
  Phoenix.PubSub.broadcast_from(MyApp.PubSub, self(), @topic, :increment)
  {:noreply, socket}
end
```

**Tradeoff:** `broadcast` is simpler and guarantees consistency (everyone processes
the same message through the same handler). `broadcast_from` risks the sender's
state diverging if the local update logic differs from the broadcast handler.

---

## Performance Considerations

1. **Fan-out cost** — Broadcasting to 10,000 subscribers = 10,000 messages. Keep
   topic scopes narrow.
2. **Message size** — PubSub copies the message to each subscriber's mailbox. Keep
   payloads small.
3. **Frequency** — Don't broadcast on every keystroke. Use `phx-debounce` on the
   client side, or implement server-side throttling with `Process.send_after` to
   batch rapid updates.
4. **Cross-node latency** — PubSub works across Erlang nodes, but messages between
   nodes on different machines have higher latency than local messages.

---

## Common Real-time Features

| Feature | Pattern |
|---|---|
| Live chat | PubSub broadcast + streams |
| Typing indicator | PubSub broadcast_from + debounce |
| Live cursors | PubSub broadcast_from + JS hook |
| Collaborative editing | PubSub + CRDTs/OT |
| Live notifications | Per-user topic + PubSub |
| Real-time dashboard | PubSub + telemetry events |

---

## Exercises

1. Implement `broadcast_from` for the shared counter (optimistic update)
2. Add Phoenix.Presence for reliable online user tracking
3. Build a typing indicator that shows "User X is typing..."
4. Create a scoped chat with multiple rooms (each room = separate topic)
5. Implement rate limiting on broadcasts (max 10 messages/second per user)
