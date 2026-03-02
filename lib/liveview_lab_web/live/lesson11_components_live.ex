defmodule LiveviewLabWeb.Lesson11ComponentsLive do
  @moduledoc """
  Lesson 11: LiveComponents Deep Dive

  Key concepts:
  - Stateful LiveComponents vs stateless function components
  - Component lifecycle: mount → update → render
  - send_update/2 for parent → child communication
  - Slots and dynamic slot rendering
  - Component-scoped events with @myself
  """
  use LiveviewLabWeb, :live_view

  alias LiveviewLabWeb.Components.{CounterComponent, EditableCardComponent}

  def mount(_params, _session, socket) do
    cards = [
      %{id: "card-1", title: "Elixir", content: "Functional programming with immutable data"},
      %{id: "card-2", title: "Phoenix", content: "Productive web framework for Elixir"},
      %{id: "card-3", title: "LiveView", content: "Rich, real-time UX without JavaScript"}
    ]

    socket =
      socket
      |> assign(
        page_title: "Lesson 11: LiveComponents",
        cards: cards,
        last_event: nil
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/components"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">LiveComponents Deep Dive</h1>

      <%!-- SECTION 1: Stateful component --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Stateful LiveComponent</h2>
          <p class="text-sm opacity-70">
            Each <code>CounterComponent</code> has its own state, isolated from
            siblings. Events target <code>@myself</code>.
          </p>

          <div class="grid grid-cols-3 gap-3 mt-3">
            <.live_component
              module={CounterComponent}
              id="counter-a"
              label="Alpha"
              color="primary"
            />
            <.live_component
              module={CounterComponent}
              id="counter-b"
              label="Beta"
              color="secondary"
            />
            <.live_component
              module={CounterComponent}
              id="counter-c"
              label="Gamma"
              color="accent"
            />
          </div>

          <div class="mt-3 flex gap-2">
            <button phx-click="reset_counter" phx-value-id="counter-a" class="btn btn-xs btn-outline">
              Reset Alpha (via send_update)
            </button>
            <button phx-click="reset_counter" phx-value-id="counter-b" class="btn btn-xs btn-outline">
              Reset Beta
            </button>
            <button phx-click="reset_counter" phx-value-id="counter-c" class="btn btn-xs btn-outline">
              Reset Gamma
            </button>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: Editable cards with lifecycle --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Component Lifecycle & Communication</h2>
          <p class="text-sm opacity-70">
            Editable cards demonstrating <code>update/2</code> callback,
            parent ↔ child event flow.
          </p>

          <div class="grid gap-3 mt-3">
            <.live_component
              :for={card <- @cards}
              module={EditableCardComponent}
              id={card.id}
              title={card.title}
              content={card.content}
            />
          </div>

          <div :if={@last_event} class="mt-3 p-2 bg-base-300 rounded text-xs font-mono">
            Last event: {@last_event}
          </div>
        </div>
      </div>

      <%!-- SECTION 3: Function components with slots --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Function Components & Slots</h2>
          <p class="text-sm opacity-70">
            Stateless function components with named slots —
            zero overhead, pure rendering.
          </p>

          <div class="grid gap-3 mt-3">
            <.info_panel type="info">
              <:title>Function Components</:title>
              <:body>
                Defined with <code>def component_name(assigns)</code>.
                No process, no state. Just a render function.
              </:body>
            </.info_panel>

            <.info_panel type="warning">
              <:title>When to Use What</:title>
              <:body>
                Use <strong>LiveComponent</strong> when you need isolated state or
                lifecycle hooks. Use <strong>function components</strong> for
                everything else — they're simpler and faster.
              </:body>
            </.info_panel>
          </div>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><strong>LiveComponent</strong> = stateful, runs in parent's process, <code>@myself</code> for targeted events</li>
            <li><strong>Function component</strong> = stateless, just a render function, use slots</li>
            <li><code>send_update/2</code> — parent sends data to a child component by ID</li>
            <li>Lifecycle: <code>mount/1 → update/2 → render/1</code> (mount only on first render)</li>
            <li>Prefer function components; reach for LiveComponent only when you need state</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # Slot-based function component
  attr :type, :string, default: "info"
  slot :title, required: true
  slot :body, required: true

  defp info_panel(assigns) do
    ~H"""
    <div class={"alert alert-#{@type}"}>
      <div>
        <h3 class="font-bold">{render_slot(@title)}</h3>
        <div class="text-sm">{render_slot(@body)}</div>
      </div>
    </div>
    """
  end

  # -- Events --

  def handle_event("reset_counter", %{"id" => id}, socket) do
    send_update(CounterComponent, id: id, reset: true)
    {:noreply, assign(socket, last_event: "Parent sent reset to #{id}")}
  end

  def handle_info({:card_saved, card_id, title}, socket) do
    {:noreply, assign(socket, last_event: "Card #{card_id} saved: \"#{title}\"")}
  end
end
