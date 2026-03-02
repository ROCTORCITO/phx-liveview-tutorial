# Lesson 9: Real-time Streaming

## Overview

This lesson covers patterns for streaming data to the client in real-time — token
by token, chunk by chunk, or as a continuous log. These patterns power LLM chat
interfaces, progress indicators, and live tailing UIs.

**Source file:** `lib/liveview_lab_web/live/lesson9_streaming_live.ex`

---

## Core Pattern: Task + send + handle_info

The fundamental streaming pattern in LiveView:

```
┌─────────────┐      send(lv, msg)      ┌──────────────┐
│  Task/       │ ──────────────────────► │  LiveView    │
│  GenServer   │                         │  process     │
│  (producer)  │                         │              │
└─────────────┘                          │ handle_info  │
                                         │   → assign   │
                                         │   → re-render│
                                         └──────────────┘
```

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, streaming: false, text: "")}
end

def handle_event("start", _, socket) do
  # Capture the LiveView's PID *before* entering the task.
  # Inside Task.start/1, self() would return the Task's PID,
  # not the LiveView's — so we bind it here.
  lv = self()

  Task.start(fn ->
    for chunk <- produce_chunks() do
      Process.sleep(50)
      send(lv, {:chunk, chunk})
    end
    send(lv, :done)
  end)

  {:noreply, assign(socket, streaming: true, text: "")}
end

def handle_info({:chunk, chunk}, socket) do
  {:noreply, assign(socket, text: socket.assigns.text <> chunk)}
end

def handle_info(:done, socket) do
  {:noreply, assign(socket, streaming: false)}
end
```

> **Why `lv = self()` before the task?** `Task.start/1` spawns a new process.
> Inside that process, `self()` returns the *task's* PID, not the LiveView's.
> We capture the LiveView PID beforehand so the task can `send` messages to it.

---

## Pattern 1: Token-by-Token Streaming (LLM Style)

Used for: Chat AI responses, typewriter effects, real-time transcription.

```elixir
def handle_event("ask", %{"prompt" => prompt}, socket) do
  lv = self()

  Task.start(fn ->
    for token <- tokenize(response) do
      Process.sleep(Enum.random(30..120))  # Simulate varying latency
      send(lv, {:token, token})
    end
    send(lv, :stream_complete)
  end)

  {:noreply, assign(socket, streaming: true, response: "")}
end

def handle_info({:token, token}, socket) do
  {:noreply, assign(socket, response: socket.assigns.response <> token)}
end
```

**Template pattern — append to text:**
```heex
<div class="response">
  {@response}
  <span :if={@streaming} class="animate-pulse">|</span>
</div>
```

**How the diff works:** LiveView tracks which assigns changed and sends the new
value over the WebSocket. The full accumulated string is sent each time. On the
client side, LiveView's DOM patching engine replaces the text node content — it
operates at the DOM node level (not individual characters), but since only one text
node changed, the update is very fast.

### Production Considerations

For real LLM streaming (OpenAI, Anthropic APIs), your API client library will have
its own streaming format. Here's a generalized pattern:

```elixir
def handle_event("ask", %{"prompt" => prompt}, socket) do
  lv = self()

  Task.start(fn ->
    # Your LLM client returns a Stream/Enumerable of chunks
    stream = MyApp.LLM.stream_completion(prompt)

    Enum.each(stream, fn
      {:chunk, text} -> send(lv, {:token, text})
      :done -> send(lv, :stream_complete)
      {:error, reason} -> send(lv, {:stream_error, reason})
    end)
  end)

  {:noreply, assign(socket, streaming: true, response: "")}
end
```

> Note: The exact return format depends on your API client library (e.g., `req`
> with SSE streaming). Adapt the pattern-matching to your library's conventions.

---

## Pattern 2: Progress Streaming

Used for: File uploads, batch processing, ETL jobs, deployments.

```elixir
def handle_event("start_job", _, socket) do
  lv = self()
  total_steps = 100

  Task.start(fn ->
    for i <- 1..total_steps do
      perform_step(i)
      send(lv, {:progress, round(i / total_steps * 100)})
    end
    send(lv, :complete)
  end)

  {:noreply, assign(socket, progress: 0)}
end

def handle_info({:progress, pct}, socket) do
  {:noreply, assign(socket, progress: pct)}
end
```

**Template:**
```heex
<progress class="progress" value={@progress} max="100" />
<span>{@progress}%</span>
```

**Optimization:** Don't send every single update — throttle to avoid flooding the
LiveView process mailbox:
```elixir
# Only send every 2% — reduces 100 messages to 50
if rem(i, max(div(total_steps, 50), 1)) == 0 do
  send(lv, {:progress, round(i / total_steps * 100)})
end
```

---

## Pattern 3: Live Log Tail

Used for: Server logs, build output, deployment logs, monitoring.

```elixir
def handle_info({:log_line, line}, socket) do
  # Cap at 500 lines to prevent unbounded memory growth.
  # Assigns are held in process memory and re-diffed on every render,
  # so unbounded growth will degrade performance and eventually crash the process.
  lines = Enum.take(socket.assigns.log_lines ++ [line], -500)
  {:noreply, assign(socket, log_lines: lines)}
end
```

> Note: The list append + take approach is O(n) per message. This is fine for
> moderate volumes (a few messages per second), but for high-volume logs, use
> streams instead.

**With a JS Hook for auto-scroll:**
```javascript
Hooks.ScrollBottom = {
  mounted() { this.scrollToBottom() },
  updated() { this.scrollToBottom() },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
```

**For high-volume logs, use streams instead.** Streams don't hold items in server
memory and only send the insert instruction, avoiding the growing diff cost:
```elixir
def handle_info({:log_line, line}, socket) do
  entry = %{id: System.unique_integer([:positive]), text: line}
  {:noreply, stream_insert(socket, :log_lines, entry)}
end
```

---

## Task Supervision

For production code, use `Task.Supervisor` instead of bare `Task.start`:

- `Task.start` is fire-and-forget and unlinked — if the task crashes, there is no
  logging, no cleanup, and no backpressure. On app shutdown, orphaned tasks may be
  killed without finishing.
- `Task.Supervisor` ensures tasks are properly supervised, logged on failure, and
  terminated cleanly on shutdown.

```elixir
# In application.ex children list
{Task.Supervisor, name: MyApp.StreamingSupervisor}

# In LiveView
Task.Supervisor.start_child(MyApp.StreamingSupervisor, fn ->
  lv = self()  # Still the LiveView PID here — start_child runs the fn in a new process
  # ... wait, this is wrong! self() here is the *child* task's PID.
end)
```

**Correct usage:**
```elixir
def handle_event("start", _, socket) do
  lv = self()  # Capture LiveView PID *before* spawning

  Task.Supervisor.start_child(MyApp.StreamingSupervisor, fn ->
    # streaming work — send results back to `lv`
    send(lv, {:chunk, data})
  end)

  {:noreply, assign(socket, streaming: true)}
end
```

---

## Cancellation

To cancel a running stream:

```elixir
def handle_event("start", _, socket) do
  lv = self()
  {:ok, pid} = Task.start(fn -> stream_work(lv) end)
  {:noreply, assign(socket, task_pid: pid, streaming: true)}
end

def handle_event("cancel", _, socket) do
  if pid = socket.assigns.task_pid do
    # :kill is a hard stop — no cleanup, no `after` blocks run.
    # For graceful shutdown, consider sending a :cancel message
    # that the task checks periodically.
    Process.exit(pid, :kill)
  end
  {:noreply, assign(socket, streaming: false, task_pid: nil)}
end
```

**Better approach: `start_async` + `cancel_async`**

`start_async` is for **one-shot** async operations (a single result handled by
`handle_async/3`). It is NOT designed for streaming multiple messages — for that,
use the `Task.start` + `send` pattern above. But for cancellable one-shot tasks:

```elixir
def handle_event("start", _, socket) do
  {:noreply, start_async(socket, :my_task, fn -> expensive_computation() end)}
end

def handle_event("cancel", _, socket) do
  {:noreply, cancel_async(socket, :my_task)}
end

# Called when the task completes
def handle_async(:my_task, {:ok, result}, socket) do
  {:noreply, assign(socket, result: result)}
end

# Called when the task is cancelled or crashes
def handle_async(:my_task, {:exit, _reason}, socket) do
  {:noreply, socket}
end
```

> On LiveView disconnect, `start_async` tasks are automatically cleaned up by the
> framework — they stop receiving results, but the task process itself is not killed
> (it just runs to completion with no one listening).

---

## Performance Tips

1. **Throttle updates** — Don't send on every byte; batch updates to reduce mailbox flooding
2. **Cap accumulation** — Set max length for accumulated text/lines to bound memory
3. **Use streams for lists** — If streaming list items, use `stream_insert` not append to assign
4. **Handle disconnects** — Tasks should detect dead LiveView PIDs gracefully
5. **IOdata for large text** — Elixir supports IO lists (nested lists of binaries) which avoid
   copying when concatenating. Instead of `acc <> chunk`, use `[acc | chunk]` and flatten only
   at render time. This is an advanced optimization for very high-throughput scenarios.

---

## Exercises

1. Build a streaming file download progress bar with actual byte counts
2. Implement cancellation with a "Stop" button that kills the streaming task
3. Create a streaming diff viewer that highlights new characters as they arrive
4. Build a multi-stream UI showing 3 parallel tasks with independent progress
