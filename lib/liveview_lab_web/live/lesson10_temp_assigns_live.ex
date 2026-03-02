defmodule LiveviewLabWeb.Lesson10TempAssignsLive do
  @moduledoc """
  Lesson 10: Temporary Assigns & Pagination

  Key concepts:
  - Why `temporary_assigns` existed (legacy pattern)
  - Streams as the modern replacement
  - Stream-based pagination (efficient, no full list on server)
  - Comparing regular assigns vs streams memory usage
  """
  use LiveviewLabWeb, :live_view

  @page_size 20

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 10: Temporary Assigns & Pagination",
        page: 1,
        end_of_data: false,
        loading: false,
        append_count: 0
      )
      |> stream(:append_items, [])
      |> stream(:items, generate_items_for_page(1))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/temporary-assigns"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Temporary Assigns & Pagination</h1>

      <%!-- SECTION 1: Memory comparison --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Memory: Regular Assigns vs Streams</h2>
          <p class="text-sm opacity-70">
            Regular assigns keep all data in the LiveView process memory.
            Streams only track insert/delete diffs — items live on the client only.
          </p>

          <div class="overflow-x-auto mt-3">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Strategy</th>
                  <th>Server Memory</th>
                  <th>Client DOM</th>
                  <th>Use Case</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><code>assign</code></td>
                  <td class="text-error">O(n) — all items kept</td>
                  <td>Full diff on change</td>
                  <td>Small, frequently accessed data</td>
                </tr>
                <tr class="opacity-50">
                  <td><code>temporary_assigns</code></td>
                  <td class="text-warning">O(1) — cleared after render</td>
                  <td>Append only (deprecated)</td>
                  <td>Legacy — use streams instead</td>
                </tr>
                <tr>
                  <td><code>stream</code></td>
                  <td class="text-success">O(1) — never stored</td>
                  <td>Granular insert/delete</td>
                  <td>Large lists, pagination, feeds</td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="mt-2 p-3 bg-warning/10 border border-warning/30 rounded text-sm">
            <strong>Note:</strong> <code>temporary_assigns</code> with
            <code>phx-update="append"</code> is deprecated in Phoenix 1.8+.
            Use <code>stream/3</code> for all new code.
          </div>
        </div>
      </div>

      <%!-- SECTION 2: Stream append demo (replaces temporary_assigns) --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Stream Append (Modern Pattern)</h2>
          <p class="text-sm opacity-70">
            Using <code>stream_insert/4</code> to append items.
            Server stores zero items — only diffs are tracked.
          </p>

          <button phx-click="add_stream_items" class="btn btn-sm btn-primary mt-2">
            Append 10 items (server stores nothing)
          </button>

          <div id="append-items" phx-update="stream" class="mt-3 space-y-1 max-h-48 overflow-y-auto">
            <div
              :for={{dom_id, item} <- @streams.append_items}
              id={dom_id}
              class="p-2 bg-base-300 rounded text-sm"
            >
              #{item.id} — {item.text}
            </div>
          </div>
          <p class="text-xs opacity-50 mt-1">
            Items appended: {@append_count} · Server memory: 0 items (stream)
          </p>
        </div>
      </div>

      <%!-- SECTION 3: Stream-based infinite scroll --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Stream Pagination (Infinite Scroll)</h2>
          <p class="text-sm opacity-70">
            Uses <code>stream/3</code> for server-efficient pagination.
            Click "Load More" to fetch the next page.
          </p>

          <div id="stream-items" phx-update="stream" class="mt-3 space-y-1 max-h-80 overflow-y-auto">
            <div
              :for={{dom_id, item} <- @streams.items}
              id={dom_id}
              class="p-2 bg-base-300 rounded text-sm flex justify-between"
            >
              <span>#{item.id} — {item.text}</span>
              <span class="badge badge-ghost badge-xs">page {item.page}</span>
            </div>
          </div>

          <div class="mt-3 text-center">
            <button
              :if={not @end_of_data}
              phx-click="load_more"
              class={["btn btn-sm btn-outline", @loading && "loading"]}
              disabled={@loading}
            >
              {if @loading, do: "Loading...", else: "Load More"}
            </button>
            <p :if={@end_of_data} class="text-sm opacity-50">
              All data loaded.
            </p>
          </div>
          <p class="text-xs opacity-50 mt-1">
            Page: {@page} · Items on server: 0 (stream)
          </p>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>stream/3</code> replaces <code>temporary_assigns</code> — more flexible and efficient</li>
            <li>Streams support insert, delete, reset — temporary_assigns only appended</li>
            <li><code>stream_insert(socket, :items, item)</code> to append one item</li>
            <li><code>stream(socket, :items, list)</code> to append a batch</li>
            <li><code>stream(socket, :items, [], reset: true)</code> to clear everything</li>
            <li>For infinite scroll: load page, stream items in, increment page counter</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  def handle_event("add_stream_items", _params, socket) do
    count = socket.assigns.append_count
    new_items = generate_items(count + 1, 10)

    socket =
      socket
      |> stream(:append_items, new_items)
      |> assign(append_count: count + 10)

    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    send(self(), :do_load_more)
    {:noreply, assign(socket, loading: true)}
  end

  def handle_info(:do_load_more, socket) do
    # Simulate network delay
    Process.sleep(300)

    page = socket.assigns.page + 1
    items = generate_items_for_page(page)
    end_of_data = page >= 5

    socket =
      socket
      |> stream(:items, items)
      |> assign(page: page, end_of_data: end_of_data, loading: false)

    {:noreply, socket}
  end

  # -- Data generation --

  defp generate_items(start, count) do
    for i <- start..(start + count - 1) do
      %{id: i, text: "Item #{i} — #{random_label()}"}
    end
  end

  defp generate_items_for_page(page) do
    start = (page - 1) * @page_size + 1

    for i <- start..(start + @page_size - 1) do
      %{id: i, text: "Item #{i} — #{random_label()}", page: page}
    end
  end

  defp random_label do
    Enum.random([
      "Elixir process spawned",
      "GenServer callback",
      "Ecto query result",
      "Phoenix channel msg",
      "Telemetry event fired",
      "Supervision tree restart",
      "ETS table lookup",
      "Binary pattern match",
      "Distributed node ping",
      "Registry lookup complete"
    ])
  end
end
