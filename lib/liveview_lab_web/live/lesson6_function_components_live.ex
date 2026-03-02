defmodule LiveviewLabWeb.Lesson6FunctionComponentsLive do
  @moduledoc """
  Lesson 6: Function Components

  Key concepts:
  - Defining private function components within a LiveView module
  - Declarative attrs with defaults and required validation
  - Named slots (required and optional) and inner_block
  - Slot arguments with render_slot/2 and the :let pattern
  - Global attributes with attr :rest, :global and {@rest}
  """
  use LiveviewLabWeb, :live_view

  @languages [
    %{name: "Elixir", year: 2011, typing: "Dynamic"},
    %{name: "Rust", year: 2010, typing: "Static"},
    %{name: "Python", year: 1991, typing: "Dynamic"},
    %{name: "Go", year: 2009, typing: "Static"},
    %{name: "TypeScript", year: 2012, typing: "Static"},
    %{name: "Ruby", year: 1995, typing: "Dynamic"}
  ]

  @code_card_snippet ~S'''
  attr :variant, :string, default: "default", values: ~w(default primary warning)
  slot :header, required: true
  slot :footer
  slot :inner_block, required: true

  defp lesson_card(assigns) do
    ~H"""
    <div class={card_classes(@variant)}>
      <div class={card_header_classes(@variant)}>
        {render_slot(@header)}
      </div>
      <div class="card-body pt-3">
        {render_slot(@inner_block)}
        <div :if={@footer != []} class="card-actions justify-end mt-3">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end
  '''

  @code_table_snippet ~S'''
  <%!-- Usage: :let receives each row from render_slot(col, row) --%>
  <.data_table rows={@languages}>
    <:col :let={lang} label="Language">
      <span class="font-semibold">{lang.name}</span>
    </:col>
    <:col :let={lang} label="Year Created">
      <span class="font-mono">{lang.year}</span>
    </:col>
    <:col :let={lang} label="Type System">
      <span class={badge_class(lang.typing)}>{lang.typing}</span>
    </:col>
  </.data_table>
  '''

  @code_button_snippet ~S'''
  attr :variant, :string, default: "primary", values: ~w(primary secondary ghost)
  attr :rest, :global, include: ~w(data-tip id)
  slot :inner_block, required: true

  defp fancy_button(assigns) do
    ~H"""
    <button class={fancy_button_classes(@variant)} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  <%!-- Extra attrs pass through: --%>
  <.fancy_button variant="ghost" phx-click="clicked" data-tip="hi" class="btn-wide">
    Click me
  </.fancy_button>
  '''

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 6: Function Components",
        languages: @languages,
        button_clicks: [],
        code_card: @code_card_snippet,
        code_table: @code_table_snippet,
        code_button: @code_button_snippet
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">&larr; Home</.link>
        <.link navigate={"/notes/function-components"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Function Components</h1>

      <%!-- SECTION 1: Card Component Showcase --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Card Component Showcase</h2>
          <p class="text-sm opacity-70">
            A private <code>lesson_card/1</code> function component with
            <code>attr :variant</code> (default/primary/warning),
            a required <code>:header</code> slot, optional <code>:footer</code> slot,
            and <code>:inner_block</code> for body content.
          </p>

          <div class="grid gap-4 mt-3 md:grid-cols-3">
            <.lesson_card variant="default">
              <:header>Default Variant</:header>
              This card uses the <strong>default</strong> variant styling.
              It inherits the base card appearance with neutral colors.
              Function components are stateless and zero-overhead.
              <:footer>
                <button class="btn btn-sm btn-ghost">Learn More</button>
              </:footer>
            </.lesson_card>

            <.lesson_card variant="primary">
              <:header>Primary Variant</:header>
              This card uses the <strong>primary</strong> variant with
              an accent border and highlighted header. Great for
              drawing attention to important content.
              <:footer>
                <button class="btn btn-sm btn-primary">Get Started</button>
              </:footer>
            </.lesson_card>

            <.lesson_card variant="warning">
              <:header>Warning Variant</:header>
              This card uses the <strong>warning</strong> variant for
              cautionary information. The border and header reflect
              the warning color from your DaisyUI theme.
            </.lesson_card>
          </div>

          <div class="mt-3 p-3 bg-base-300 rounded text-xs font-mono whitespace-pre-wrap"><code>{@code_card}</code></div>
        </div>
      </div>

      <%!-- SECTION 2: Data Table with Slot Arguments --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Data Table with Slot Arguments</h2>
          <p class="text-sm opacity-70">
            A <code>data_table/1</code> component with <code>attr :rows</code> (list, required)
            and a <code>:col</code> slot that receives each row via <code>render_slot(col, row)</code>.
            The caller uses <code>:let</code> to destructure each row.
          </p>

          <div class="mt-3">
            <.data_table rows={@languages}>
              <:col :let={lang} label="Language">
                <span class="font-semibold">{lang.name}</span>
              </:col>
              <:col :let={lang} label="Year Created">
                <span class="font-mono">{lang.year}</span>
              </:col>
              <:col :let={lang} label="Type System">
                <span class={[
                  "badge badge-sm",
                  lang.typing == "Static" && "badge-primary",
                  lang.typing == "Dynamic" && "badge-secondary"
                ]}>
                  {lang.typing}
                </span>
              </:col>
            </.data_table>
          </div>

          <div class="mt-3 p-3 bg-base-300 rounded text-xs font-mono whitespace-pre-wrap"><code>{@code_table}</code></div>
        </div>
      </div>

      <%!-- SECTION 3: Global Attributes Demo --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Global Attributes Demo</h2>
          <p class="text-sm opacity-70">
            A <code>fancy_button/1</code> component with <code>attr :variant</code> and
            <code>attr :rest, :global</code>. Any extra HTML attributes passed to the
            component are forwarded to the underlying element via <code>&#123;@rest&#125;</code>.
          </p>

          <div class="flex flex-wrap gap-3 mt-3">
            <div class="tooltip" data-tip="Primary variant with data-tip on wrapper">
              <.fancy_button variant="primary" phx-click="button_clicked" phx-value-name="primary">
                Primary Button
              </.fancy_button>
            </div>

            <.fancy_button
              variant="secondary"
              phx-click="button_clicked"
              phx-value-name="secondary"
              class="btn-wide"
            >
              Secondary (class override: btn-wide)
            </.fancy_button>

            <.fancy_button
              variant="ghost"
              phx-click="button_clicked"
              phx-value-name="ghost"
              data-tip="I have a data-tip attribute"
              id="ghost-btn"
            >
              Ghost (with data-tip &amp; id)
            </.fancy_button>
          </div>

          <div :if={@button_clicks != []} class="mt-3 p-3 bg-base-300 rounded text-sm">
            <p class="font-semibold text-xs mb-1">Click Log (via phx-click passed through @rest):</p>
            <div :for={click <- Enum.take(@button_clicks, 8)} class="text-xs font-mono opacity-70">
              {click}
            </div>
          </div>

          <div class="mt-3 p-3 bg-base-300 rounded text-xs font-mono whitespace-pre-wrap"><code>{@code_button}</code></div>
        </div>
      </div>

      <%!-- SECTION 4: Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li>
              <strong>Function components</strong> are just functions that take assigns and return HEEx
              &mdash; no process, no state, zero overhead
            </li>
            <li>
              <code>attr :name, :type, default: val</code> declares compile-time-checked attributes
            </li>
            <li>
              <code>slot :name, required: true</code> declares named slots;
              <code>slot :inner_block</code> is the default slot
            </li>
            <li>
              <code>render_slot(@col, row)</code> passes <code>row</code> as a slot argument;
              the caller receives it via <code>:let=&#123;row&#125;</code>
            </li>
            <li>
              <code>attr :rest, :global</code> collects all extra HTML attributes;
              spread them with <code>&#123;@rest&#125;</code> in the template
            </li>
            <li>
              <code>:global</code> accepts <code>include: ~w(data-tip id)</code> to explicitly
              allow specific extra attributes
            </li>
            <li>
              Private <code>defp</code> components are module-scoped;
              use <code>def</code> and import the module to share across views
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Events --

  def handle_event("button_clicked", %{"name" => name}, socket) do
    timestamp = Time.utc_now() |> Time.truncate(:second)
    entry = "[#{timestamp}] Clicked: #{name} button (via @rest pass-through)"
    clicks = [entry | socket.assigns.button_clicks]
    {:noreply, assign(socket, button_clicks: clicks)}
  end

  # ============================================================================
  # Function Component: lesson_card/1
  # ============================================================================

  attr :variant, :string, default: "default", values: ~w(default primary warning)
  slot :header, required: true
  slot :footer
  slot :inner_block, required: true

  defp lesson_card(assigns) do
    ~H"""
    <div class={card_classes(@variant)}>
      <div class={card_header_classes(@variant)}>
        <h3 class="font-bold text-sm">{render_slot(@header)}</h3>
      </div>
      <div class="card-body pt-3 text-sm">
        {render_slot(@inner_block)}
        <div :if={@footer != []} class="card-actions justify-end mt-3">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  defp card_classes("default"), do: "card bg-base-300 border border-base-content/10"
  defp card_classes("primary"), do: "card bg-base-300 border-2 border-primary/40"
  defp card_classes("warning"), do: "card bg-base-300 border-2 border-warning/40"

  defp card_header_classes("default"), do: "px-4 pt-4 pb-0"
  defp card_header_classes("primary"), do: "px-4 pt-4 pb-0 text-primary"
  defp card_header_classes("warning"), do: "px-4 pt-4 pb-0 text-warning"

  # ============================================================================
  # Function Component: data_table/1
  # ============================================================================

  attr :rows, :list, required: true
  slot :col, required: true do
    attr :label, :string, required: true
  end

  defp data_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm table-zebra">
        <thead>
          <tr>
            <th :for={col <- @col}>{col.label}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows}>
            <td :for={col <- @col}>
              {render_slot(col, row)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # ============================================================================
  # Function Component: fancy_button/1
  # ============================================================================

  attr :variant, :string, default: "primary", values: ~w(primary secondary ghost)
  attr :rest, :global, include: ~w(data-tip id)
  slot :inner_block, required: true

  defp fancy_button(assigns) do
    ~H"""
    <button class={fancy_button_classes(@variant)} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp fancy_button_classes("primary"), do: "btn btn-primary btn-sm"
  defp fancy_button_classes("secondary"), do: "btn btn-secondary btn-sm"
  defp fancy_button_classes("ghost"), do: "btn btn-ghost btn-sm"
end
