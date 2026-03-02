defmodule LiveviewLabWeb.Components.EditableCardComponent do
  @moduledoc """
  A stateful LiveComponent demonstrating:
  - Editing state within a component
  - Component-scoped forms
  - Parent notification via send/2
  - update/2 lifecycle receiving new props
  """
  use LiveviewLabWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, editing: false)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(title: assigns.title, content: assigns.content)
      |> assign_new(:form, fn -> to_form(%{"title" => assigns.title, "content" => assigns.content}) end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="card bg-base-300">
      <div class="card-body p-3">
        <div :if={not @editing}>
          <div class="flex justify-between items-center">
            <h3 class="font-bold">{@title}</h3>
            <button phx-click="edit" phx-target={@myself} class="btn btn-ghost btn-xs">
              Edit
            </button>
          </div>
          <p class="text-sm opacity-70 mt-1">{@content}</p>
        </div>

        <.form :if={@editing} for={@form} phx-submit="save" phx-target={@myself} class="space-y-2">
          <input
            type="text"
            name="title"
            value={@form[:title].value}
            class="input input-bordered input-sm w-full"
          />
          <textarea
            name="content"
            class="textarea textarea-bordered textarea-sm w-full"
            rows="2"
          >{@form[:content].value}</textarea>
          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary btn-xs">Save</button>
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost btn-xs">
              Cancel
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("edit", _params, socket) do
    {:noreply, assign(socket, editing: true)}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, editing: false)}
  end

  def handle_event("save", %{"title" => title, "content" => content}, socket) do
    # Notify parent
    send(self(), {:card_saved, socket.assigns.id, title})

    socket =
      socket
      |> assign(title: title, content: content, editing: false)
      |> assign(form: to_form(%{"title" => title, "content" => content}))

    {:noreply, socket}
  end
end
