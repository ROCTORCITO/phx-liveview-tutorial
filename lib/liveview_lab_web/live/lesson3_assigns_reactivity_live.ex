defmodule LiveviewLabWeb.Lesson3AssignsReactivityLive do
  @moduledoc """
  Lesson 3: Assigns & Reactivity

  Key concepts:
  - Assigns are the state of a LiveView — changing them triggers re-render
  - Change tracking: LiveView only re-renders template parts that depend on changed assigns
  - Forms with to_form/2 and manual validation (no Ecto changesets)
  - Reactive UI patterns with phx-change
  """
  use LiveviewLabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    now = now_str()

    profile_form =
      %{"username" => "", "email" => "", "bio" => ""}
      |> to_form(as: "profile")

    socket =
      socket
      |> assign(
        page_title: "Lesson 3: Assigns & Reactivity",
        # Reactive Explorer assigns
        name: "World",
        color: "#3b82f6",
        count: 1,
        name_rendered_at: now,
        color_rendered_at: now,
        count_rendered_at: now,
        # Form assigns
        profile_form: profile_form,
        profile_errors: %{},
        profile_saved: false
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">← Home</.link>
        <.link navigate={"/notes/assigns-reactivity"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Assigns & Reactivity</h1>

      <%!-- SECTION 1: Reactive Explorer --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Reactive Explorer</h2>
          <p class="text-sm opacity-70">
            Change the inputs below. Each output card tracks when it was last re-rendered.
            Only the card whose assign changed will get a new timestamp, demonstrating
            LiveView's <strong>change tracking</strong>.
          </p>

          <form phx-change="update_reactive" class="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-3">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-xs">Name</span>
              </label>
              <input
                type="text"
                value={@name}
                phx-debounce="200"
                name="name"
                class="input input-bordered input-sm"
                placeholder="Enter a name..."
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text text-xs">Color</span>
              </label>
              <input
                type="color"
                value={@color}
                name="color"
                class="input input-bordered input-sm h-9 p-1 cursor-pointer"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text text-xs">Count</span>
              </label>
              <input
                type="range"
                min="1"
                max="20"
                value={@count}
                name="count"
                class="range range-sm range-primary mt-2"
              />
            </div>
          </form>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-4">
            <.reactive_card
              label="Name"
              value={"Hello, #{@name}!"}
              rendered_at={@name_rendered_at}
              color="primary"
            />
            <.reactive_card
              label="Color"
              value={@color}
              rendered_at={@color_rendered_at}
              color="secondary"
              is_color={true}
            />
            <.reactive_card
              label="Count"
              value={Enum.map(1..@count, fn _ -> "*" end) |> Enum.join(" ")}
              rendered_at={@count_rendered_at}
              color="accent"
            />
          </div>

          <p class="text-xs opacity-50 mt-2">
            Notice: changing "Name" only updates the Name card's timestamp.
            Other cards keep their old timestamp — LiveView skips unchanged parts.
          </p>
        </div>
      </div>

      <%!-- SECTION 2: Live Form with Validation --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Live Form with Validation</h2>
          <p class="text-sm opacity-70">
            A "Create Profile" form with real-time validation via <code>phx-change="validate"</code>.
            Uses <code>to_form/2</code> with manual error checking — no Ecto changesets needed.
          </p>

          <div :if={@profile_saved} class="alert alert-success mt-3">
            <span>Profile saved successfully!</span>
          </div>

          <.form
            for={@profile_form}
            phx-change="validate"
            phx-submit="save"
            class="mt-3 space-y-1"
          >
            <.input
              field={@profile_form[:username]}
              label="Username"
              placeholder="At least 3 characters"
              autocomplete="off"
            />

            <.input
              field={@profile_form[:email]}
              type="email"
              label="Email"
              placeholder="must contain @"
              autocomplete="off"
            />

            <.input
              field={@profile_form[:bio]}
              type="textarea"
              label="Bio"
              placeholder="Tell us about yourself (max 200 chars)"
              rows="3"
              autocomplete="off"
            />

            <div class="flex items-center justify-between mt-4">
              <div class="text-xs opacity-50">
                Bio: {String.length(@profile_form[:bio].value || "")}/200 characters
              </div>
              <button type="submit" class="btn btn-primary btn-sm">
                Save Profile
              </button>
            </div>
          </.form>

          <div class="mt-3 p-3 bg-base-300 rounded">
            <div class="text-xs font-bold opacity-60 uppercase tracking-wide mb-1">
              Current Form Data (assigns)
            </div>
            <div class="text-xs font-mono whitespace-pre-wrap bg-base-100 p-2 rounded">
              {inspect(%{username: @profile_form[:username].value, email: @profile_form[:email].value, bio: @profile_form[:bio].value}, pretty: true)}
            </div>
          </div>
        </div>
      </div>

      <%!-- Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><strong>Assigns = state.</strong> Calling <code>assign(socket, key: value)</code> stores data and triggers re-render</li>
            <li><strong>Change tracking:</strong> LiveView tracks which assigns changed and only re-renders affected template parts</li>
            <li><code>phx-change</code> fires on every input change — ideal for live search, validation, reactive UIs</li>
            <li><code>to_form/2</code> wraps a map into a form struct — works without Ecto for simple cases</li>
            <li>Errors in forms are tuples: <code>{~s({"message", []})}</code> — the second element is validation metadata</li>
            <li>Use <code>phx-debounce</code> to throttle rapid input events (default: "blur" for most inputs)</li>
            <li><code>Phoenix.Component.used_input?/1</code> controls when errors display (only after user interaction)</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Function Components --

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :rendered_at, :string, required: true
  attr :color, :string, default: "primary"
  attr :is_color, :boolean, default: false

  defp reactive_card(assigns) do
    ~H"""
    <div class="p-3 bg-base-300 rounded border-l-4 border-l-primary">
      <div class="text-xs opacity-60 uppercase tracking-wide">{@label}</div>
      <div class="mt-1">
        <div :if={@is_color} class="flex items-center gap-2">
          <div class="w-6 h-6 rounded" style={"background-color: #{@value}"}></div>
          <span class="font-mono text-sm">{@value}</span>
        </div>
        <div :if={!@is_color} class="font-bold text-lg">{@value}</div>
      </div>
      <div class="text-xs opacity-40 mt-2 font-mono">
        rendered: {@rendered_at}
      </div>
    </div>
    """
  end

  # -- Events --

  @impl true
  def handle_event("update_reactive", %{"_target" => ["name"], "name" => name}, socket) do
    {:noreply, assign(socket, name: name, name_rendered_at: now_str())}
  end

  def handle_event("update_reactive", %{"_target" => ["color"], "color" => color}, socket) do
    {:noreply, assign(socket, color: color, color_rendered_at: now_str())}
  end

  def handle_event("update_reactive", %{"_target" => ["count"], "count" => count}, socket) do
    count = String.to_integer(count)
    {:noreply, assign(socket, count: count, count_rendered_at: now_str())}
  end

  @impl true
  def handle_event("validate", %{"profile" => params}, socket) do
    errors = validate_profile(params)

    form =
      params
      |> to_form(as: "profile", errors: build_form_errors(errors))

    {:noreply, assign(socket, profile_form: form, profile_saved: false)}
  end

  @impl true
  def handle_event("save", %{"profile" => params}, socket) do
    errors = validate_profile(params)

    if errors == %{} do
      form =
        params
        |> to_form(as: "profile")

      {:noreply, assign(socket, profile_form: form, profile_saved: true)}
    else
      form =
        params
        |> to_form(as: "profile", errors: build_form_errors(errors))

      {:noreply, assign(socket, profile_form: form, profile_saved: false)}
    end
  end

  # -- Private --

  defp validate_profile(params) do
    errors = %{}

    username = Map.get(params, "username", "")
    email = Map.get(params, "email", "")
    bio = Map.get(params, "bio", "")

    errors =
      if String.length(username) < 3 and String.length(username) > 0 do
        Map.put(errors, :username, "must be at least 3 characters")
      else
        if String.length(username) == 0 do
          Map.put(errors, :username, "can't be blank")
        else
          errors
        end
      end

    errors =
      if String.length(email) > 0 and not String.contains?(email, "@") do
        Map.put(errors, :email, "must contain @")
      else
        if String.length(email) == 0 do
          Map.put(errors, :email, "can't be blank")
        else
          errors
        end
      end

    errors =
      if String.length(bio) > 200 do
        Map.put(errors, :bio, "must be at most 200 characters (currently #{String.length(bio)})")
      else
        errors
      end

    errors
  end

  defp build_form_errors(errors) do
    Enum.map(errors, fn {field, message} ->
      {field, {message, []}}
    end)
  end

  defp now_str do
    Time.utc_now() |> Time.truncate(:millisecond) |> Time.to_string()
  end
end
