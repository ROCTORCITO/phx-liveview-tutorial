defmodule LiveviewLabWeb.Components.CounterComponent do
  @moduledoc """
  A stateful LiveComponent demonstrating:
  - Isolated state per instance
  - Event handling with @myself
  - send_update for external resets
  - update/2 callback
  """
  use LiveviewLabWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end

  def update(%{reset: true}, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, label: assigns.label, color: assigns.color)}
  end

  def render(assigns) do
    ~H"""
    <div class="card bg-base-300 text-center">
      <div class="card-body p-3">
        <h3 class="text-sm font-semibold">{@label}</h3>
        <span class={"text-2xl font-bold text-#{@color}"}>{@count}</span>
        <div class="flex justify-center gap-1 mt-1">
          <button phx-click="dec" phx-target={@myself} class="btn btn-xs btn-circle btn-outline">
            −
          </button>
          <button phx-click="inc" phx-target={@myself} class="btn btn-xs btn-circle btn-outline">
            +
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count - 1)}
  end
end
