defmodule LiveviewLabWeb.Lesson8StreamsLive do
  @moduledoc """
  Lesson 8: Streams & Async

  Key concepts:
  - `stream/3` for efficient large-list rendering (no server-side storage of list items)
  - `stream_insert/3`, `stream_delete/2` for granular updates
  - `assign_async/3` for non-blocking initial data loads
  - Combining streams + async for responsive UIs
  """
  use LiveviewLabWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Lesson 8: Streams & Async")
      |> stream(:messages, [])
      |> assign(form: to_form(%{"body" => ""}))
      |> assign(counter: 0)
      |> assign_async(:slow_data, fn -> fetch_slow_data() end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/streams"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Streams & Async</h1>

      <%!-- SECTION 1: assign_async demo --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">assign_async — Non-blocking Data Load</h2>
          <p class="text-sm opacity-70">
            Data loads in a spawned task. The page renders immediately, then fills in when ready.
          </p>
          <div class="mt-2 p-3 bg-base-300 rounded font-mono text-sm">
            <.async_result :let={data} assign={@slow_data}>
              <:loading>
                <span class="loading loading-dots loading-sm"></span>
                Loading slow data...
              </:loading>
              <:failed :let={_reason}>
                <span class="text-error">Failed to load data</span>
              </:failed>
              <div class="space-y-1">
                <div :for={item <- data} class="flex gap-2">
                  <span class="badge badge-primary badge-sm">{item.id}</span>
                  <span>{item.label}</span>
                </div>
              </div>
            </.async_result>
          </div>
          <div class="mt-2">
            <button phx-click="reload_async" class="btn btn-sm btn-outline">
              Reload (triggers async again)
            </button>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: Streams demo --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">stream/3 — Efficient List Rendering</h2>
          <p class="text-sm opacity-70">
            Items sent via stream are <strong>not stored on the server</strong>.
            Only DOM patches are sent. Perfect for chat, feeds, logs.
          </p>

          <.form for={@form} phx-submit="add_message" class="flex gap-2 mt-2">
            <input
              type="text"
              name="body"
              value={@form[:body].value}
              placeholder="Type a message..."
              class="input input-bordered input-sm flex-1"
              autofocus
            />
            <button type="submit" class="btn btn-primary btn-sm">Send</button>
          </.form>

          <div class="flex gap-2 mt-2">
            <button phx-click="add_batch" class="btn btn-sm btn-outline">
              Add 100 items
            </button>
            <button phx-click="reset_stream" class="btn btn-sm btn-outline btn-warning">
              Reset stream
            </button>
          </div>

          <div
            id="messages"
            phx-update="stream"
            class="mt-3 max-h-64 overflow-y-auto space-y-1"
          >
            <div
              :for={{dom_id, msg} <- @streams.messages}
              id={dom_id}
              class="flex items-center gap-2 p-2 bg-base-300 rounded text-sm"
            >
              <span class="badge badge-ghost badge-sm font-mono">{msg.id}</span>
              <span class="flex-1">{msg.body}</span>
              <button
                phx-click="delete_message"
                phx-value-id={msg.id}
                class="btn btn-ghost btn-xs text-error"
              >
                ×
              </button>
            </div>
          </div>
          <p class="text-xs opacity-50 mt-1">
            Messages sent: {@counter} · Server stores 0 list items (stream)
          </p>
        </div>
      </div>

      <%!-- SECTION 3: Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>stream/3</code> — items are only on the client; server tracks insert/delete diffs</li>
            <li><code>stream_insert/3</code> — append/prepend/replace a single item</li>
            <li><code>stream_delete/2</code> — remove an item by its DOM id</li>
            <li><code>assign_async/3</code> — spawns a task, renders loading/ok/failed states</li>
            <li>Combine both: stream for the list, assign_async for initial fetch</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  def handle_event("add_message", %{"body" => body}, socket) when byte_size(body) > 0 do
    counter = socket.assigns.counter + 1
    msg = %{id: counter, body: body}

    socket =
      socket
      |> stream_insert(:messages, msg)
      |> assign(counter: counter)
      |> assign(form: to_form(%{"body" => ""}))

    {:noreply, socket}
  end

  def handle_event("add_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("delete_message", %{"id" => id}, socket) do
    {:noreply, stream_delete(socket, :messages, %{id: String.to_integer(id)})}
  end

  def handle_event("add_batch", _params, socket) do
    start = socket.assigns.counter + 1
    items = for i <- start..(start + 99), do: %{id: i, body: "Batch item ##{i}"}

    socket =
      socket
      |> stream(:messages, items)
      |> assign(counter: start + 99)

    {:noreply, socket}
  end

  def handle_event("reset_stream", _params, socket) do
    {:noreply, stream(socket, :messages, [], reset: true)}
  end

  def handle_event("reload_async", _params, socket) do
    {:noreply, assign_async(socket, :slow_data, fn -> fetch_slow_data() end, reset: true)}
  end

  # -- Private --

  defp fetch_slow_data do
    # Simulate a slow API call
    Process.sleep(1500)

    data =
      for i <- 1..5 do
        %{id: i, label: "Async-loaded item #{i} (fetched at #{Time.utc_now() |> Time.truncate(:second)})"}
      end

    {:ok, %{slow_data: data}}
  end
end
