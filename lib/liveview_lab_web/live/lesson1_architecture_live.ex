defmodule LiveviewLabWeb.Lesson1ArchitectureLive do
  @moduledoc """
  Lesson 1: LiveView Architecture

  Key concepts:
  - Every LiveView is a BEAM process (one per connected user)
  - Two-phase mount: first HTTP (static HTML), then WebSocket upgrade
  - LiveView sends diffs, not full HTML — only changed parts are patched
  - The socket is a plain data structure holding assigns
  """
  use LiveviewLabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    pid = self()
    memory = get_memory()

    socket =
      socket
      |> assign(
        page_title: "Lesson 1: LiveView Architecture",
        connected: connected?(socket),
        transport: if(connected?(socket), do: "Connected (WebSocket)", else: "HTTP (static)"),
        pid: inspect(pid),
        memory_bytes: memory,
        items: [],
        counter: 0,
        diff_clicks: 0,
        mount_time: now_str()
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/architecture"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">LiveView Architecture</h1>

      <%!-- SECTION 1: Connection Inspector --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Connection Inspector</h2>
          <p class="text-sm opacity-70">
            LiveView mounts twice: first as a static HTTP render (for SEO/initial paint),
            then again over WebSocket. Watch the values change between phases.
          </p>

          <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div class="p-3 bg-base-300 rounded">
              <div class="text-xs opacity-60 uppercase tracking-wide">connected?</div>
              <div class={[
                "text-lg font-bold font-mono mt-1",
                @connected && "text-success",
                !@connected && "text-warning"
              ]}>
                {@connected |> to_string()}
              </div>
            </div>

            <div class="p-3 bg-base-300 rounded">
              <div class="text-xs opacity-60 uppercase tracking-wide">Transport</div>
              <div class={[
                "text-lg font-bold font-mono mt-1",
                @connected && "text-success",
                !@connected && "text-warning"
              ]}>
                {@transport}
              </div>
            </div>

            <div class="p-3 bg-base-300 rounded">
              <div class="text-xs opacity-60 uppercase tracking-wide">self() PID</div>
              <div class="text-lg font-bold font-mono mt-1 text-primary">
                {@pid}
              </div>
            </div>
          </div>

          <p class="text-xs opacity-50 mt-2">
            Mount time: {@mount_time} — The PID changes between static render and WebSocket
            because they are different BEAM processes.
          </p>
        </div>
      </div>

      <%!-- SECTION 2: Process Memory --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Process Memory</h2>
          <p class="text-sm opacity-70">
            Each LiveView process has its own memory. Adding items to assigns increases
            the process memory. This is tracked via <code>:erlang.process_info(self(), :memory)</code>.
          </p>

          <div class="mt-3 flex items-center gap-4">
            <div class="p-3 bg-base-300 rounded flex-1">
              <div class="text-xs opacity-60 uppercase tracking-wide">Process Memory</div>
              <div class="text-2xl font-bold font-mono mt-1 text-accent">
                {format_bytes(@memory_bytes)}
              </div>
              <div class="text-xs opacity-50 mt-1">{@memory_bytes} bytes</div>
            </div>

            <div class="p-3 bg-base-300 rounded flex-1">
              <div class="text-xs opacity-60 uppercase tracking-wide">Items in Assign</div>
              <div class="text-2xl font-bold font-mono mt-1">
                {length(@items)}
              </div>
            </div>
          </div>

          <div class="flex gap-2 mt-3">
            <button phx-click="add_items" class="btn btn-sm btn-primary">
              Add 1,000 Items
            </button>
            <button phx-click="clear_items" class="btn btn-sm btn-outline btn-warning">
              Clear Items
            </button>
            <button phx-click="refresh_memory" class="btn btn-sm btn-outline">
              Refresh Memory
            </button>
          </div>

          <p class="text-xs opacity-50 mt-2">
            Click "Add 1,000 Items" multiple times and watch memory grow. Each item is stored
            in the process heap. This is why streams exist for large lists.
          </p>
        </div>
      </div>

      <%!-- SECTION 3: Diff Demo --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Diff Demo</h2>
          <p class="text-sm opacity-70">
            LiveView only sends the changed parts of the page over the WebSocket.
            Click the counter and see what a "diff" looks like vs a full page reload.
          </p>

          <div class="mt-3 flex items-center gap-6">
            <button phx-click="increment_diff" class="btn btn-lg btn-primary btn-outline">
              Count: {@diff_clicks}
            </button>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-4">
            <div class="p-3 bg-success/10 border border-success/30 rounded">
              <div class="text-xs font-bold text-success uppercase tracking-wide mb-2">
                LiveView Diff (what is sent)
              </div>
              <div class="text-xs font-mono whitespace-pre-wrap bg-base-300 p-2 rounded">
                {~s(%{"0" => "#{@diff_clicks}"})}
              </div>
              <div class="text-xs opacity-50 mt-1">
                Only the changed value is sent — a few bytes.
              </div>
            </div>

            <div class="p-3 bg-error/10 border border-error/30 rounded">
              <div class="text-xs font-bold text-error uppercase tracking-wide mb-2">
                Full Page Reload (traditional)
              </div>
              <div class="text-xs font-mono whitespace-pre-wrap bg-base-300 p-2 rounded">{full_page_example(@diff_clicks)}</div>
              <div class="text-xs opacity-50 mt-1">
                Full page = entire HTML document re-downloaded.
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li>Every connected user gets their own <strong>BEAM process</strong> — isolated memory, crash isolation, millions possible</li>
            <li><strong>Two-phase mount:</strong> first HTTP (static HTML for fast initial paint / SEO), then WebSocket upgrade (interactivity)</li>
            <li>LiveView sends <strong>diffs, not full HTML</strong> — only the changed assigns are transmitted over WebSocket</li>
            <li>The <strong>socket</strong> is a data structure (<code>{"%Phoenix.LiveView.Socket{}"}</code>) — assigns are its state</li>
            <li>Process memory grows with assigns — use <strong>streams</strong> for large lists to avoid keeping data on the server</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  @impl true
  def handle_event("add_items", _params, socket) do
    current_count = length(socket.assigns.items)
    new_items = for i <- (current_count + 1)..(current_count + 1000), do: %{id: i, data: "item-#{i}"}

    socket =
      socket
      |> assign(items: socket.assigns.items ++ new_items)
      |> assign(memory_bytes: get_memory())

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_items", _params, socket) do
    socket =
      socket
      |> assign(items: [])
      |> assign(memory_bytes: get_memory())

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_memory", _params, socket) do
    {:noreply, assign(socket, memory_bytes: get_memory())}
  end

  @impl true
  def handle_event("increment_diff", _params, socket) do
    {:noreply, assign(socket, diff_clicks: socket.assigns.diff_clicks + 1)}
  end

  # -- Private --

  defp get_memory do
    case :erlang.process_info(self(), :memory) do
      {:memory, bytes} -> bytes
      _ -> 0
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp full_page_example(count) do
    """
    <html>
      <head>...styles, scripts...</head>
      <body>
        <nav>...</nav>
        <main>
          <div class="card">
            <button>Count: #{count}</button>
          </div>
        </main>
        <footer>...</footer>
      </body>
    </html>\
    """
  end

  defp now_str do
    Time.utc_now() |> Time.truncate(:second) |> Time.to_string()
  end
end
