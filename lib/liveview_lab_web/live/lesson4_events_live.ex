defmodule LiveviewLabWeb.Lesson4EventsLive do
  @moduledoc """
  Lesson 4: Events & Bindings

  Key concepts:
  - phx-click, phx-change, phx-blur, phx-focus, phx-submit for common DOM events
  - phx-debounce and phx-throttle for controlling event frequency
  - phx-window-keydown, phx-key for keyboard events
  - phx-value-* for passing data attributes with events
  - Streams for efficient event log rendering
  """
  use LiveviewLabWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 4: Events & Bindings",
        log_counter: 0,
        # Debounce & Throttle tracking
        debounce_count: 0,
        debounce_last_value: "",
        throttle_count: 0,
        throttle_last_value: "",
        # Keyboard tracking
        last_key: nil,
        last_filtered_key: nil,
        last_value_data: nil
      )
      |> stream(:event_log, [])

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">&larr; Home</.link>
        <.link navigate={"/notes/events"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Events & Bindings</h1>

      <%!-- SECTION 1: Event Logger --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Event Logger</h2>
          <p class="text-sm opacity-70">
            Every event fires a <code>handle_event/3</code> on the server.
            Watch the log below to see events as they arrive.
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
            <%!-- Left column: event triggers --%>
            <div class="space-y-3">
              <h3 class="font-semibold text-sm">Click Events</h3>
              <div class="flex flex-wrap gap-2">
                <button phx-click="log_click" class="btn btn-sm btn-primary">
                  phx-click
                </button>
                <button phx-click="log_click_away" class="btn btn-sm btn-secondary">
                  Another click
                </button>
              </div>

              <h3 class="font-semibold text-sm">Input Events</h3>
              <form phx-change="log_change">
                <input
                  type="text"
                  placeholder="Type here (phx-change, phx-blur, phx-focus)"
                  phx-blur="log_blur"
                  phx-focus="log_focus"
                  phx-debounce="200"
                  name="demo_input"
                  class="input input-bordered input-sm w-full"
                />
              </form>

              <h3 class="font-semibold text-sm">Form Submit</h3>
              <form phx-submit="log_submit" class="flex gap-2">
                <input
                  type="text"
                  name="form_value"
                  placeholder="Submit me..."
                  class="input input-bordered input-sm flex-1"
                />
                <button type="submit" class="btn btn-sm btn-accent">
                  phx-submit
                </button>
              </form>
            </div>

            <%!-- Right column: event log --%>
            <div>
              <div class="flex items-center justify-between mb-2">
                <h3 class="font-semibold text-sm">Live Event Log</h3>
                <button phx-click="clear_log" class="btn btn-xs btn-outline btn-warning">
                  Clear
                </button>
              </div>
              <div
                id="event-log"
                phx-update="stream"
                class="bg-base-300 rounded p-2 max-h-56 overflow-y-auto space-y-1 font-mono text-xs"
              >
                <div
                  :for={{dom_id, entry} <- @streams.event_log}
                  id={dom_id}
                  class="flex gap-2 border-b border-base-content/10 pb-1"
                >
                  <span class="opacity-50 shrink-0">{entry.timestamp}</span>
                  <span class={"badge badge-xs #{entry.badge_class} shrink-0"}>{entry.event}</span>
                  <span class="opacity-70 truncate">{entry.payload}</span>
                </div>
              </div>
              <p class="text-xs opacity-50 mt-1">
                Events logged: {@log_counter}
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: Debounce & Throttle Playground --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Debounce & Throttle Playground</h2>
          <p class="text-sm opacity-70">
            <code>phx-debounce</code> waits until typing stops.
            <code>phx-throttle</code> fires at most once per interval.
            Both are set to <strong>500ms</strong>. Type rapidly to see the difference.
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
            <%!-- Debounce column --%>
            <div class="p-3 bg-base-300 rounded space-y-2">
              <h3 class="font-semibold text-sm">
                phx-debounce="500"
              </h3>
              <p class="text-xs opacity-60">
                Waits 500ms after you <em>stop</em> typing before sending the event.
              </p>
              <form phx-change="debounce_changed">
                <input
                  type="text"
                  name="debounce_input"
                  placeholder="Type rapidly here..."
                  phx-debounce="500"
                  class="input input-bordered input-sm w-full"
                />
              </form>
              <div class="text-sm space-y-1">
                <div>
                  Events reached server:
                  <span class="badge badge-primary badge-sm font-mono">{@debounce_count}</span>
                </div>
                <div class="truncate">
                  Last value:
                  <code class="text-xs">{@debounce_last_value}</code>
                </div>
              </div>
            </div>

            <%!-- Throttle column --%>
            <div class="p-3 bg-base-300 rounded space-y-2">
              <h3 class="font-semibold text-sm">
                phx-throttle="500"
              </h3>
              <p class="text-xs opacity-60">
                Sends at most once every 500ms, even if you keep typing.
              </p>
              <form phx-change="throttle_changed">
                <input
                  type="text"
                  name="throttle_input"
                  placeholder="Type rapidly here..."
                  phx-throttle="500"
                  class="input input-bordered input-sm w-full"
                />
              </form>
              <div class="text-sm space-y-1">
                <div>
                  Events reached server:
                  <span class="badge badge-secondary badge-sm font-mono">{@throttle_count}</span>
                </div>
                <div class="truncate">
                  Last value:
                  <code class="text-xs">{@throttle_last_value}</code>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-3 flex gap-2">
            <button phx-click="reset_debounce_throttle" class="btn btn-xs btn-outline">
              Reset counters
            </button>
          </div>
        </div>
      </div>

      <%!-- SECTION 3: Keyboard Events --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Keyboard Events</h2>
          <p class="text-sm opacity-70">
            <code>phx-window-keydown</code> captures keys globally.
            <code>phx-key</code> filters to specific keys.
            <code>phx-value-*</code> passes data attributes with events.
          </p>

          <div class="space-y-4 mt-3">
            <%!-- Window keydown --%>
            <div phx-window-keydown="keypress" class="p-3 bg-base-300 rounded">
              <h3 class="font-semibold text-sm mb-2">
                phx-window-keydown (captures all keys)
              </h3>
              <p class="text-xs opacity-60 mb-2">
                Press any key anywhere on the page.
              </p>
              <div class="flex items-center gap-3">
                <span class="text-sm">Last key pressed:</span>
                <kbd :if={@last_key} class="kbd kbd-lg font-mono">{@last_key}</kbd>
                <span :if={!@last_key} class="text-sm opacity-40">Press any key...</span>
              </div>
            </div>

            <%!-- Filtered key --%>
            <div
              phx-window-keydown="special_key"
              phx-key="Enter"
              class="p-3 bg-base-300 rounded"
            >
              <h3 class="font-semibold text-sm mb-2">
                phx-key="Enter" (filtered)
              </h3>
              <p class="text-xs opacity-60 mb-2">
                Only the Enter key triggers this handler. Try pressing other keys -- nothing happens.
              </p>
              <div class="flex items-center gap-3">
                <span class="text-sm">Enter detected:</span>
                <span :if={@last_filtered_key} class="badge badge-success">{@last_filtered_key}</span>
                <span :if={!@last_filtered_key} class="text-sm opacity-40">
                  Press Enter...
                </span>
              </div>
            </div>

            <%!-- phx-value-* demo --%>
            <div class="p-3 bg-base-300 rounded">
              <h3 class="font-semibold text-sm mb-2">
                phx-value-* (data attributes)
              </h3>
              <p class="text-xs opacity-60 mb-2">
                Each button sends different <code>phx-value-*</code> attributes
                along with the click event.
              </p>
              <div class="flex flex-wrap gap-2">
                <button
                  phx-click="value_click"
                  phx-value-color="red"
                  phx-value-size="large"
                  phx-value-id="btn-1"
                  class="btn btn-sm btn-error"
                >
                  Red / Large
                </button>
                <button
                  phx-click="value_click"
                  phx-value-color="blue"
                  phx-value-size="medium"
                  phx-value-id="btn-2"
                  class="btn btn-sm btn-info"
                >
                  Blue / Medium
                </button>
                <button
                  phx-click="value_click"
                  phx-value-color="green"
                  phx-value-size="small"
                  phx-value-id="btn-3"
                  class="btn btn-sm btn-success"
                >
                  Green / Small
                </button>
              </div>
              <div :if={@last_value_data} class="mt-2 p-2 bg-base-100 rounded text-xs font-mono">
                Received: color={@last_value_data["color"]}, size={@last_value_data["size"]}, id={@last_value_data["id"]}
              </div>
              <div :if={!@last_value_data} class="mt-2 text-xs opacity-40">
                Click a button to see phx-value-* data...
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- SECTION 4: Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>phx-click</code>, <code>phx-change</code>, <code>phx-blur</code>, <code>phx-focus</code> — standard DOM event bindings</li>
            <li><code>phx-submit</code> — form submission; always pair with a <code>&lt;form&gt;</code> tag</li>
            <li><code>phx-debounce="ms"</code> — delays the event until input stops for the given ms</li>
            <li><code>phx-throttle="ms"</code> — sends at most one event per interval, drops extras</li>
            <li><code>phx-window-keydown</code> — global key listener; <code>phx-key</code> filters to a specific key</li>
            <li><code>phx-value-*</code> — attach arbitrary data to events (received as string params)</li>
            <li>Use <code>stream/3</code> for event logs and other append-heavy lists</li>
            <li>All events arrive as <code>handle_event(name, params, socket)</code> on the server</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Event Logger handlers --

  def handle_event("log_click", _params, socket) do
    {:noreply, append_log(socket, "phx-click", "Button clicked", "badge-primary")}
  end

  def handle_event("log_click_away", _params, socket) do
    {:noreply, append_log(socket, "phx-click", "Another button clicked", "badge-secondary")}
  end

  def handle_event("log_change", %{"demo_input" => value}, socket) do
    {:noreply, append_log(socket, "phx-change", "value: \"#{value}\"", "badge-accent")}
  end

  def handle_event("log_blur", _params, socket) do
    {:noreply, append_log(socket, "phx-blur", "Input lost focus", "badge-warning")}
  end

  def handle_event("log_focus", _params, socket) do
    {:noreply, append_log(socket, "phx-focus", "Input gained focus", "badge-info")}
  end

  def handle_event("log_submit", %{"form_value" => value}, socket) do
    {:noreply, append_log(socket, "phx-submit", "Submitted: \"#{value}\"", "badge-success")}
  end

  def handle_event("clear_log", _params, socket) do
    socket =
      socket
      |> stream(:event_log, [], reset: true)
      |> assign(log_counter: 0)

    {:noreply, socket}
  end

  # -- Debounce & Throttle handlers --

  def handle_event("debounce_changed", %{"debounce_input" => value}, socket) do
    socket =
      socket
      |> assign(
        debounce_count: socket.assigns.debounce_count + 1,
        debounce_last_value: value
      )
      |> append_log("debounce", "value: \"#{value}\"", "badge-primary")

    {:noreply, socket}
  end

  def handle_event("throttle_changed", %{"throttle_input" => value}, socket) do
    socket =
      socket
      |> assign(
        throttle_count: socket.assigns.throttle_count + 1,
        throttle_last_value: value
      )
      |> append_log("throttle", "value: \"#{value}\"", "badge-secondary")

    {:noreply, socket}
  end

  def handle_event("reset_debounce_throttle", _params, socket) do
    {:noreply,
     assign(socket,
       debounce_count: 0,
       debounce_last_value: "",
       throttle_count: 0,
       throttle_last_value: ""
     )}
  end

  # -- Keyboard event handlers --

  def handle_event("keypress", %{"key" => key}, socket) do
    socket =
      socket
      |> assign(last_key: key)
      |> append_log("keydown", "key: \"#{key}\"", "badge-ghost")

    {:noreply, socket}
  end

  def handle_event("special_key", %{"key" => "Enter"}, socket) do
    now = Time.utc_now() |> Time.truncate(:second) |> Time.to_string()

    socket =
      socket
      |> assign(last_filtered_key: "Enter at #{now}")
      |> append_log("phx-key", "Enter pressed (filtered)", "badge-success")

    {:noreply, socket}
  end

  # -- phx-value-* handler --

  def handle_event("value_click", params, socket) do
    data = %{
      "color" => params["color"],
      "size" => params["size"],
      "id" => params["id"]
    }

    socket =
      socket
      |> assign(last_value_data: data)
      |> append_log("phx-value-*", "color=#{data["color"]} size=#{data["size"]} id=#{data["id"]}", "badge-neutral")

    {:noreply, socket}
  end

  # -- Private helpers --

  defp append_log(socket, event, payload, badge_class) do
    counter = socket.assigns.log_counter + 1
    now = Time.utc_now() |> Time.truncate(:second) |> Time.to_string()

    entry = %{
      id: counter,
      timestamp: now,
      event: event,
      payload: payload,
      badge_class: badge_class
    }

    socket
    |> stream_insert(:event_log, entry, at: 0)
    |> assign(log_counter: counter)
  end
end
