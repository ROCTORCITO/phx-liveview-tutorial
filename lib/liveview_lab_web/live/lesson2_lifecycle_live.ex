defmodule LiveviewLabWeb.Lesson2LifecycleLive do
  @moduledoc """
  Lesson 2: Lifecycle Callbacks

  Key concepts:
  - mount/3 — initializes state, runs twice (static + connected)
  - handle_params/3 — runs on mount AND on every patch (URL change)
  - handle_event/3 — responds to client-side user events
  - handle_info/2 — receives messages from other processes or self
  - render/1 — called automatically when assigns change
  """
  use LiveviewLabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 2: Lifecycle Callbacks",
        log: [log_entry("mount", "mount/3 called (connected=#{connected?(socket)})")],
        active_tab: "mount",
        timer_running: false,
        timer_ref: nil,
        tick_count: 0
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "mount")

    socket =
      socket
      |> assign(active_tab: tab)
      |> append_log("handle_params", "handle_params/3 — tab=#{tab}")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/lifecycle"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Lifecycle Callbacks</h1>

      <%!-- SECTION 1: Lifecycle Logger --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Lifecycle Logger</h2>
          <p class="text-sm opacity-70">
            Every callback invocation is logged below with a timestamp. Trigger different
            callbacks using the buttons to see the lifecycle in action.
          </p>

          <div class="flex flex-wrap gap-2 mt-3">
            <button phx-click="trigger_event" class="btn btn-sm btn-primary">
              Trigger Event
            </button>
            <button phx-click="send_self" class="btn btn-sm btn-secondary">
              Send Self Message
            </button>
            <button
              phx-click="toggle_timer"
              class={["btn btn-sm", @timer_running && "btn-error" || "btn-accent"]}
            >
              {if @timer_running, do: "Stop Timer", else: "Start Timer"}
            </button>
            <button phx-click="clear_log" class="btn btn-sm btn-outline btn-warning">
              Clear Log
            </button>
          </div>

          <div :if={@timer_running} class="mt-2 flex items-center gap-2">
            <span class="loading loading-ring loading-sm text-accent"></span>
            <span class="text-sm text-accent">
              Timer running — tick #{@tick_count} (handle_info fires every second)
            </span>
          </div>

          <div class="mt-3 p-3 bg-base-300 rounded max-h-72 overflow-y-auto" id="lifecycle-log">
            <div :if={@log == []} class="text-sm opacity-40">No log entries yet...</div>
            <div
              :for={entry <- Enum.reverse(@log)}
              class="flex items-start gap-2 text-xs font-mono py-0.5 border-b border-base-content/5 last:border-0"
            >
              <span class="opacity-40 shrink-0">{entry.time}</span>
              <span class={[
                "badge badge-xs shrink-0",
                callback_badge_class(entry.callback)
              ]}>
                {entry.callback}
              </span>
              <span class="opacity-80">{entry.message}</span>
            </div>
          </div>

          <p class="text-xs opacity-50 mt-1">
            Log capped at 50 entries. Newest at top.
          </p>
        </div>
      </div>

      <%!-- SECTION 2: Tab Switcher via handle_params --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Tab Switcher via handle_params</h2>
          <p class="text-sm opacity-70">
            These tabs use <code>{"<.link patch=...>"}</code> to update the URL query param.
            <code>handle_params/3</code> fires on each switch — check the log above!
          </p>

          <div class="tabs tabs-bordered mt-3">
            <.link
              patch={~p"/lessons/lifecycle?tab=mount"}
              class={["tab", @active_tab == "mount" && "tab-active"]}
            >
              mount
            </.link>
            <.link
              patch={~p"/lessons/lifecycle?tab=events"}
              class={["tab", @active_tab == "events" && "tab-active"]}
            >
              events
            </.link>
            <.link
              patch={~p"/lessons/lifecycle?tab=info"}
              class={["tab", @active_tab == "info" && "tab-active"]}
            >
              info
            </.link>
          </div>

          <div class="mt-4 p-4 bg-base-300 rounded min-h-[120px]">
            <div :if={@active_tab == "mount"}>
              <h3 class="font-bold text-sm mb-2">mount/3</h3>
              <ul class="text-sm space-y-1 opacity-80 list-disc list-inside">
                <li>Called once on static render (HTTP) and once on WebSocket connect</li>
                <li>Signature: <code>mount(params, session, socket)</code></li>
                <li><code>params</code> — URL path params (e.g., <code>{~s(%{"id" => "42"})}</code>)</li>
                <li><code>session</code> — session data from the Plug pipeline</li>
                <li>Use <code>connected?(socket)</code> to check if on WebSocket</li>
                <li>Returns <code>{"{:ok, socket}"}</code></li>
              </ul>
            </div>

            <div :if={@active_tab == "events"}>
              <h3 class="font-bold text-sm mb-2">handle_event/3</h3>
              <ul class="text-sm space-y-1 opacity-80 list-disc list-inside">
                <li>Handles client-side events: <code>phx-click</code>, <code>phx-change</code>, <code>phx-submit</code></li>
                <li>Signature: <code>handle_event(event, params, socket)</code></li>
                <li><code>event</code> — the event name string</li>
                <li><code>params</code> — payload map (form data, phx-value-* attrs)</li>
                <li>Returns <code>{"{:noreply, socket}"}</code> or <code>{"{:reply, map, socket}"}</code></li>
                <li>Only fires on connected (WebSocket) LiveViews</li>
              </ul>
            </div>

            <div :if={@active_tab == "info"}>
              <h3 class="font-bold text-sm mb-2">handle_info/2</h3>
              <ul class="text-sm space-y-1 opacity-80 list-disc list-inside">
                <li>Receives messages from <code>send/2</code>, <code>Process.send_after/3</code>, PubSub, etc.</li>
                <li>Signature: <code>handle_info(message, socket)</code></li>
                <li>Essential for PubSub broadcasts and timer-based updates</li>
                <li>The LiveView process is a GenServer — this is its <code>handle_info</code></li>
                <li>Use pattern matching to route different message types</li>
                <li>Returns <code>{"{:noreply, socket}"}</code></li>
              </ul>
            </div>
          </div>

          <p class="text-xs opacity-50 mt-2">
            Active tab: <code>{@active_tab}</code> — URL updates without full page reload (patch navigation).
          </p>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>mount/3</code> — runs twice: once for static render, once on WebSocket connect</li>
            <li><code>handle_params/3</code> — fires on mount AND on every <code>patch</code> navigation (URL changes)</li>
            <li><code>handle_event/3</code> — responds to user interactions (<code>phx-click</code>, <code>phx-submit</code>, etc.)</li>
            <li><code>handle_info/2</code> — receives async messages (timers, PubSub, <code>send/2</code>)</li>
            <li><code>render/1</code> — called automatically whenever assigns change; you rarely call it directly</li>
            <li>Use <code>{"@impl true"}</code> to mark callbacks — compiler will warn about typos</li>
            <li>Lifecycle order on mount: <code>{"mount -> handle_params -> render"}</code></li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  @impl true
  def handle_event("trigger_event", _params, socket) do
    socket = append_log(socket, "handle_event", "handle_event/3 — event=\"trigger_event\"")
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_self", _params, socket) do
    send(self(), :self_message)
    socket = append_log(socket, "handle_event", "handle_event/3 — event=\"send_self\" (message dispatched via send/2)")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_timer", _params, socket) do
    if socket.assigns.timer_running do
      # Stop the timer
      if socket.assigns.timer_ref, do: Process.cancel_timer(socket.assigns.timer_ref)

      socket =
        socket
        |> assign(timer_running: false, timer_ref: nil, tick_count: 0)
        |> append_log("handle_event", "handle_event/3 — timer stopped")

      {:noreply, socket}
    else
      # Start the timer
      ref = Process.send_after(self(), :tick, 1000)

      socket =
        socket
        |> assign(timer_running: true, timer_ref: ref, tick_count: 0)
        |> append_log("handle_event", "handle_event/3 — timer started (1s interval)")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_log", _params, socket) do
    {:noreply, assign(socket, log: [])}
  end

  # -- Info handlers --

  @impl true
  def handle_info(:self_message, socket) do
    socket = append_log(socket, "handle_info", "handle_info/2 — received :self_message")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.timer_running do
      tick_count = socket.assigns.tick_count + 1
      ref = Process.send_after(self(), :tick, 1000)

      socket =
        socket
        |> assign(tick_count: tick_count, timer_ref: ref)
        |> append_log("handle_info", "handle_info/2 — :tick ##{tick_count}")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # -- Private --

  defp append_log(socket, callback, message) do
    entry = log_entry(callback, message)
    log = Enum.take([entry | socket.assigns.log], 50)
    assign(socket, log: log)
  end

  defp log_entry(callback, message) do
    %{
      time: Time.utc_now() |> Time.truncate(:millisecond) |> Time.to_string(),
      callback: callback,
      message: message
    }
  end

  defp callback_badge_class("mount"), do: "badge-primary"
  defp callback_badge_class("handle_params"), do: "badge-secondary"
  defp callback_badge_class("handle_event"), do: "badge-accent"
  defp callback_badge_class("handle_info"), do: "badge-warning"
  defp callback_badge_class(_), do: "badge-ghost"
end
