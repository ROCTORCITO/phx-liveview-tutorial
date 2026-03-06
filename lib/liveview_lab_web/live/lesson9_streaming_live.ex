defmodule LiveviewLabWeb.Lesson9StreamingLive do
  @moduledoc """
  Lesson 9: Real-time Streaming

  Key concepts:
  - Token-by-token / chunk-by-chunk streaming to the UI
  - Using `send/2` from async tasks to push incremental updates
  - Progress indicators with assign updates
  - Simulating LLM-style streaming responses
  """
  use LiveviewLabWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 9: Real-time Streaming",
        streaming: false,
        stream_text: "",
        progress: 0,
        progress_running: false,
        log_lines: []
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/streaming"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Real-time Streaming</h1>

      <%!-- SECTION 1: Token streaming (LLM-style) --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Token-by-Token Streaming</h2>
          <p class="text-sm opacity-70">
            Simulates LLM-style token streaming. Each token arrives via
            <code>{"send(self(), {:token, token})"}</code> from an async task.
          </p>

          <div class="mt-2 p-4 bg-base-300 rounded min-h-[80px] font-mono text-sm whitespace-pre-wrap">
            {@stream_text}<span :if={@streaming} class="animate-pulse">▊</span>
            <span :if={@stream_text == "" and not @streaming} class="opacity-40">
              Click "Start Streaming" to begin...
            </span>
          </div>

          <div class="flex gap-2 mt-2">
            <button
              phx-click="start_stream"
              class="btn btn-primary btn-sm"
              disabled={@streaming}
            >
              {if @streaming, do: "Streaming...", else: "Start Streaming"}
            </button>
            <button phx-click="clear_stream" class="btn btn-sm btn-outline" disabled={@streaming}>
              Clear
            </button>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: Progress bar streaming --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Progress Streaming</h2>
          <p class="text-sm opacity-70">
            An async task sends progress updates. The LiveView re-renders only the
            progress bar — minimal DOM patching.
          </p>

          <div class="mt-3">
            <div class="flex justify-between text-xs mb-1">
              <span>Progress</span>
              <span>{@progress}%</span>
            </div>
            <progress class="progress progress-primary w-full" value={@progress} max="100">
            </progress>
          </div>

          <button
            phx-click="start_progress"
            class="btn btn-sm btn-secondary mt-2"
            disabled={@progress_running}
          >
            {if @progress_running, do: "Processing...", else: "Start Process"}
          </button>
        </div>
      </div>

      <%!-- SECTION 3: Live log tail --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Live Log Tail</h2>
          <p class="text-sm opacity-70">
            Simulates tailing a log file. New lines stream in from a background task.
          </p>

          <div
            id="log-container"
            class="mt-2 p-3 bg-neutral text-neutral-content rounded font-mono text-xs max-h-48 overflow-y-auto"
            phx-hook="ScrollBottom"
          >
            <div :for={line <- @log_lines}>{line}</div>
            <div :if={@log_lines == []} class="opacity-40">No log output yet...</div>
          </div>

          <div class="flex gap-2 mt-2">
            <button phx-click="start_logs" class="btn btn-sm btn-accent">
              Generate Logs
            </button>
            <button phx-click="clear_logs" class="btn btn-sm btn-outline">Clear</button>
          </div>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li>Use <code>Task.start</code> + <code>send(lv_pid, msg)</code> for streaming</li>
            <li><code>handle_info/2</code> receives each chunk and updates assigns</li>
            <li>LiveView only sends the diff — even appending text is efficient</li>
            <li>For production LLM streaming, same pattern works with real API chunks</li>
            <li>JS Hooks (like <code>ScrollBottom</code>) complement streaming UIs</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- All handle_event clauses grouped --

  def handle_event("start_stream", _params, socket) do
    lv = self()

    Task.start(fn ->
      tokens = tokenize_text()

      for token <- tokens do
        Process.sleep(Enum.random(30..120))
        send(lv, {:token, token})
      end

      send(lv, :stream_done)
    end)

    {:noreply, assign(socket, streaming: true, stream_text: "")}
  end

  def handle_event("clear_stream", _params, socket) do
    {:noreply, assign(socket, stream_text: "")}
  end

  def handle_event("start_progress", _params, socket) do
    lv = self()

    Task.start(fn ->
      for i <- 1..100 do
        Process.sleep(Enum.random(20..60))
        send(lv, {:progress, i})
      end

      send(lv, :progress_done)
    end)

    {:noreply, assign(socket, progress: 0, progress_running: true)}
  end

  def handle_event("start_logs", _params, socket) do
    lv = self()

    Task.start(fn ->
      for i <- 1..20 do
        Process.sleep(Enum.random(100..400))
        ts = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:millisecond)
        level = Enum.random(~w[INFO DEBUG WARN ERROR])
        msg = Enum.random(log_messages())
        send(lv, {:log_line, "[#{ts}] [#{level}] #{msg} (line #{i})"})
      end
    end)

    {:noreply, socket}
  end

  def handle_event("clear_logs", _params, socket) do
    {:noreply, assign(socket, log_lines: [])}
  end

  # -- All handle_info clauses grouped --

  def handle_info({:token, token}, socket) do
    {:noreply, assign(socket, stream_text: socket.assigns.stream_text <> token)}
  end

  def handle_info(:stream_done, socket) do
    {:noreply, assign(socket, streaming: false)}
  end

  def handle_info({:progress, value}, socket) do
    {:noreply, assign(socket, progress: value)}
  end

  def handle_info(:progress_done, socket) do
    {:noreply, assign(socket, progress_running: false)}
  end

  def handle_info({:log_line, line}, socket) do
    # Keep last 200 lines
    lines = Enum.take(socket.assigns.log_lines ++ [line], -200)
    {:noreply, assign(socket, log_lines: lines)}
  end

  # -- Data --

  defp tokenize_text do
    """
    Phoenix LiveView enables real-time, server-rendered HTML without writing \
    JavaScript. When you combine LiveView with async tasks, you can stream data \
    to the client token by token — just like modern LLM chat interfaces. \
    Each token triggers a minimal DOM patch, keeping bandwidth low. \
    The server process stays responsive because streaming happens in a separate Task. \
    This pattern is production-ready and scales well with proper supervision.
    """
    |> String.graphemes()
    |> Enum.chunk_every(Enum.random(1..3))
    |> Enum.map(&Enum.join/1)
  end

  defp log_messages do
    [
      "Request processed successfully",
      "Cache miss for key user:session:42",
      "Database query completed in 12ms",
      "WebSocket connection established",
      "Background job enqueued: email_send",
      "Rate limit check passed",
      "Auth token refreshed",
      "Healthcheck endpoint hit",
      "Static asset served from CDN",
      "PubSub message broadcast to 3 subscribers"
    ]
  end
end
