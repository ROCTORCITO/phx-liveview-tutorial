defmodule LiveviewLabWeb.Lesson12PubsubLive do
  @moduledoc """
  Lesson 12: PubSub & Presence

  Key concepts:
  - Phoenix.PubSub for cross-process communication
  - Broadcasting events to all connected LiveViews
  - Shared state patterns (live counters, collaborative editing hints)
  - Topic-based pub/sub architecture
  """
  use LiveviewLabWeb, :live_view

  @topic "lesson5:lobby"

  def mount(_params, _session, socket) do
    user_id = "user-#{:rand.uniform(9999)}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveviewLab.PubSub, @topic)
      broadcast(:user_joined, %{user_id: user_id})
    end

    socket =
      socket
      |> assign(
        page_title: "Lesson 12: PubSub & Presence",
        user_id: user_id,
        shared_count: 0,
        messages: [],
        online_users: [],
        form: to_form(%{"message" => ""})
      )

    {:ok, socket}
  end

  def terminate(_reason, socket) do
    broadcast(:user_left, %{user_id: socket.assigns.user_id})
    :ok
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/pubsub"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">PubSub & Multi-User Real-time</h1>
      <p class="text-sm opacity-70">
        Open this page in multiple browser tabs to see real-time sync.
        Your ID: <code class="badge badge-sm">{@user_id}</code>
      </p>

      <%!-- SECTION 1: Shared counter --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Shared Counter (PubSub Broadcast)</h2>
          <p class="text-sm opacity-70">
            Every tab sees the same counter. Clicks broadcast to all connected LiveViews
            via <code>Phoenix.PubSub.broadcast/3</code>.
          </p>

          <div class="flex items-center gap-4 mt-3">
            <button phx-click="decrement" class="btn btn-circle btn-outline">−</button>
            <span class="text-4xl font-bold font-mono min-w-[3ch] text-center">
              {@shared_count}
            </span>
            <button phx-click="increment" class="btn btn-circle btn-outline">+</button>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: Live chat --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Live Chat (Broadcast Messages)</h2>
          <p class="text-sm opacity-70">
            Messages broadcast to the <code>lesson5:lobby</code> topic.
            All subscribers receive them instantly.
          </p>

          <div class="mt-2 p-3 bg-base-300 rounded max-h-48 overflow-y-auto space-y-1" id="chat-messages">
            <div :for={msg <- @messages} class="text-sm">
              <span class={[
                "font-mono font-bold",
                msg.user_id == @user_id && "text-primary"
              ]}>
                {msg.user_id}:
              </span>
              <span>{msg.text}</span>
            </div>
            <div :if={@messages == []} class="text-sm opacity-40">No messages yet...</div>
          </div>

          <.form for={@form} phx-submit="send_message" class="flex gap-2 mt-2">
            <input
              type="text"
              name="message"
              value={@form[:message].value}
              placeholder="Type a message..."
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-primary btn-sm">Send</button>
          </.form>
        </div>
      </div>

      <%!-- SECTION 3: Activity feed --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Activity Feed</h2>
          <p class="text-sm opacity-70">
            Join/leave events are broadcast. Each LiveView's
            <code>terminate/2</code> callback notifies others.
          </p>

          <div class="mt-2 space-y-1">
            <div :for={user <- @online_users} class="flex items-center gap-2 text-sm">
              <span class="badge badge-success badge-xs"></span>
              <span class={user == @user_id && "font-bold"}>{user}</span>
              <span :if={user == @user_id} class="text-xs opacity-50">(you)</span>
            </div>
            <div :if={@online_users == []} class="text-sm opacity-40">No users tracked yet</div>
          </div>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>PubSub.subscribe/2</code> in <code>mount/3</code> (only when <code>connected?/1</code>)</li>
            <li><code>PubSub.broadcast/3</code> sends to ALL subscribers (including self)</li>
            <li><code>handle_info/2</code> receives broadcast messages</li>
            <li><code>terminate/2</code> for cleanup (user left notifications)</li>
            <li>For real presence tracking, use <code>Phoenix.Presence</code></li>
            <li>Topics are strings — namespace them like <code>"room:lobby"</code></li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  def handle_event("increment", _params, socket) do
    broadcast(:count_changed, %{delta: 1})
    {:noreply, socket}
  end

  def handle_event("decrement", _params, socket) do
    broadcast(:count_changed, %{delta: -1})
    {:noreply, socket}
  end

  def handle_event("send_message", %{"message" => msg}, socket) when byte_size(msg) > 0 do
    broadcast(:new_message, %{user_id: socket.assigns.user_id, text: msg})
    {:noreply, assign(socket, form: to_form(%{"message" => ""}))}
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  # -- PubSub handlers --

  def handle_info({:count_changed, %{delta: delta}}, socket) do
    {:noreply, assign(socket, shared_count: socket.assigns.shared_count + delta)}
  end

  def handle_info({:new_message, msg}, socket) do
    messages = Enum.take(socket.assigns.messages ++ [msg], -50)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:user_joined, %{user_id: uid}}, socket) do
    users = Enum.uniq(socket.assigns.online_users ++ [uid])
    {:noreply, assign(socket, online_users: users)}
  end

  def handle_info({:user_left, %{user_id: uid}}, socket) do
    users = List.delete(socket.assigns.online_users, uid)
    {:noreply, assign(socket, online_users: users)}
  end

  # -- Helpers --

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(LiveviewLab.PubSub, @topic, {event, payload})
  end
end
