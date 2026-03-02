defmodule LiveviewLabWeb.Lesson13JsHooksLive do
  @moduledoc """
  Lesson 13: JS Hooks & Commands

  Key concepts:
  - JS Hooks for client-side behavior (phx-hook)
  - JS Commands (Phoenix.LiveView.JS) for DOM manipulation without roundtrips
  - push_event/3 for server → client communication
  - handle_event for client → server via pushEvent
  - Combining JS commands for complex interactions
  """
  use LiveviewLabWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 13: JS Hooks & Commands",
        clipboard_text: "Hello from LiveView! Copy me.",
        server_events: [],
        js_toggle_open: false
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/js-hooks"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">JS Hooks & Commands</h1>

      <%!-- SECTION 1: JS Commands --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">JS Commands (No Server Roundtrip)</h2>
          <p class="text-sm opacity-70">
            <code>Phoenix.LiveView.JS</code> runs DOM operations client-side.
            No WebSocket message needed.
          </p>

          <div class="space-y-3 mt-3">
            <%!-- Toggle --%>
            <div>
              <button
                phx-click={JS.toggle(to: "#js-toggle-target", in: "fade-in", out: "fade-out")}
                class="btn btn-sm btn-primary"
              >
                JS.toggle — Show/Hide
              </button>
              <div id="js-toggle-target" class="mt-2 p-3 bg-base-300 rounded text-sm">
                This element toggles with a CSS transition. No server involved!
              </div>
            </div>

            <%!-- Push/Remove class --%>
            <div>
              <button
                phx-click={
                  JS.add_class("bg-primary text-primary-content rounded p-2",
                    to: "#class-target"
                  )
                }
                class="btn btn-sm btn-secondary"
              >
                Add Classes
              </button>
              <button
                phx-click={
                  JS.remove_class("bg-primary text-primary-content rounded p-2",
                    to: "#class-target"
                  )
                }
                class="btn btn-sm btn-outline"
              >
                Remove Classes
              </button>
              <div id="class-target" class="mt-2 text-sm transition-all">
                Target element for class manipulation
              </div>
            </div>

            <%!-- Chained commands --%>
            <div>
              <button
                phx-click={
                  JS.push("server_ping")
                  |> JS.toggle(to: "#chain-indicator")
                  |> JS.transition("animate-pulse", to: "#chain-indicator")
                }
                class="btn btn-sm btn-accent"
              >
                Chained: push + toggle + transition
              </button>
              <div id="chain-indicator" class="mt-2 p-2 bg-accent/20 rounded text-sm" hidden>
                Server was pinged AND this element was toggled — in one click!
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: JS Hooks --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">JS Hooks (phx-hook)</h2>
          <p class="text-sm opacity-70">
            Hooks bridge JavaScript ↔ LiveView. Define them in <code>app.js</code>
            and reference via <code>phx-hook="HookName"</code>.
          </p>

          <%!-- Clipboard hook --%>
          <div class="mt-3">
            <h3 class="font-semibold text-sm">Clipboard Hook</h3>
            <div class="flex gap-2 mt-1">
              <input
                type="text"
                value={@clipboard_text}
                class="input input-bordered input-sm flex-1"
                readonly
              />
              <button
                id="copy-btn"
                phx-hook="Clipboard"
                data-clipboard-text={@clipboard_text}
                class="btn btn-sm btn-outline"
              >
                Copy
              </button>
            </div>
          </div>

          <%!-- Timestamp hook --%>
          <div class="mt-3">
            <h3 class="font-semibold text-sm">Local Timestamp Hook</h3>
            <p class="text-xs opacity-70">
              Server sends UTC, hook converts to local time on the client.
            </p>
            <div
              id="local-time"
              phx-hook="LocalTime"
              data-utc={DateTime.utc_now() |> DateTime.to_iso8601()}
              class="mt-1 p-2 bg-base-300 rounded text-sm font-mono"
            >
              Loading local time...
            </div>
          </div>

          <%!-- Key listener hook --%>
          <div class="mt-3">
            <h3 class="font-semibold text-sm">Keyboard Event Hook</h3>
            <p class="text-xs opacity-70">
              Hook captures keystrokes and pushes them to the server via <code>pushEvent</code>.
            </p>
            <div
              id="key-listener"
              phx-hook="KeyListener"
              tabindex="0"
              class="mt-1 p-3 bg-base-300 rounded text-sm font-mono focus:ring-2 ring-primary cursor-text"
            >
              Click here and type...
            </div>
          </div>
        </div>
      </div>

      <%!-- SECTION 3: push_event (server → client) --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">push_event (Server → Client)</h2>
          <p class="text-sm opacity-70">
            The server can push arbitrary events to JS hooks via <code>push_event/3</code>.
          </p>

          <button phx-click="trigger_confetti" class="btn btn-sm btn-primary mt-2">
            Push "confetti" event to client
          </button>

          <div
            id="confetti-target"
            phx-hook="ConfettiReceiver"
            class="mt-2 p-3 bg-base-300 rounded text-sm min-h-[40px]"
          >
            Waiting for server push...
          </div>
        </div>
      </div>

      <%!-- SECTION 4: Server events log --%>
      <div :if={@server_events != []} class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Server Event Log</h2>
          <div class="space-y-1 max-h-32 overflow-y-auto">
            <div :for={evt <- Enum.reverse(@server_events)} class="text-xs font-mono opacity-70">
              {evt}
            </div>
          </div>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>JS.*</code> commands run client-side — no WebSocket roundtrip</li>
            <li>Commands are chainable: <code>JS.push() |> JS.toggle() |> JS.transition()</code></li>
            <li>Hooks: <code>mounted()</code>, <code>updated()</code>, <code>destroyed()</code> lifecycle</li>
            <li><code>this.pushEvent(name, payload)</code> — client → server</li>
            <li><code>push_event(socket, name, payload)</code> — server → client</li>
            <li><code>this.handleEvent(name, callback)</code> — hook listens for server pushes</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  def handle_event("server_ping", _params, socket) do
    event = "[#{Time.utc_now() |> Time.truncate(:second)}] server_ping received"
    {:noreply, assign(socket, server_events: [event | socket.assigns.server_events])}
  end

  def handle_event("key_pressed", %{"key" => key}, socket) do
    event = "[#{Time.utc_now() |> Time.truncate(:second)}] Key pressed: #{key}"
    {:noreply, assign(socket, server_events: [event | socket.assigns.server_events])}
  end

  def handle_event("trigger_confetti", _params, socket) do
    socket = push_event(socket, "confetti", %{message: "Party time! 🎉", timestamp: System.system_time(:second)})
    event = "[#{Time.utc_now() |> Time.truncate(:second)}] Pushed confetti event to client"
    {:noreply, assign(socket, server_events: [event | socket.assigns.server_events])}
  end
end
