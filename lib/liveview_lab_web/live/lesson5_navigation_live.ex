defmodule LiveviewLabWeb.Lesson5NavigationLive do
  @moduledoc """
  Lesson 5: Navigation & Routing

  Key concepts:
  - `patch` vs `navigate` — same LiveView process vs new process
  - handle_params/3 for reacting to URL changes
  - URL as source of truth for filters, sorting, pagination
  - <.link patch={...}> for in-process navigation
  - <.link navigate={...}> for cross-LiveView navigation
  """
  use LiveviewLabWeb, :live_view

  @languages [
    %{name: "Elixir", year: 2011, typing: "dynamic"},
    %{name: "Rust", year: 2010, typing: "static"},
    %{name: "Go", year: 2009, typing: "static"},
    %{name: "TypeScript", year: 2012, typing: "static"},
    %{name: "Python", year: 1991, typing: "dynamic"},
    %{name: "Ruby", year: 1995, typing: "dynamic"},
    %{name: "Java", year: 1995, typing: "static"},
    %{name: "Kotlin", year: 2011, typing: "static"},
    %{name: "Swift", year: 2014, typing: "static"},
    %{name: "Haskell", year: 1990, typing: "static"},
    %{name: "Clojure", year: 2007, typing: "dynamic"},
    %{name: "Scala", year: 2004, typing: "static"},
    %{name: "Erlang", year: 1986, typing: "dynamic"},
    %{name: "C#", year: 2000, typing: "static"},
    %{name: "F#", year: 2005, typing: "static"},
    %{name: "Dart", year: 2011, typing: "static"},
    %{name: "Lua", year: 1993, typing: "dynamic"},
    %{name: "Zig", year: 2016, typing: "static"},
    %{name: "Julia", year: 2012, typing: "dynamic"},
    %{name: "Nim", year: 2008, typing: "static"}
  ]

  @page_size 5

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lesson 5: Navigation & Routing",
        pid: inspect(self()),
        mounted_at: Time.utc_now() |> Time.truncate(:second) |> Time.to_string(),
        render_count: 0,
        current_view: "list",
        # Filter demo assigns (set in handle_params)
        all_languages: @languages,
        filtered_languages: @languages,
        current_sort: "name",
        current_page: 1,
        total_pages: total_pages(),
        page_size: @page_size
      )

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    # -- Patch vs Navigate demo --
    current_view = Map.get(params, "view", "list")

    # -- URL-Driven Filters demo --
    sort = Map.get(params, "sort", "name")
    page = Map.get(params, "page", "1") |> parse_int(1)
    page = max(1, min(page, total_pages()))

    sorted = sort_languages(@languages, sort)
    paginated = paginate(sorted, page)

    socket =
      socket
      |> assign(
        current_view: current_view,
        render_count: socket.assigns.render_count + 1,
        current_sort: sort,
        current_page: page,
        filtered_languages: paginated
      )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate="/" class="btn btn-ghost btn-sm">&larr; Home</.link>
        <.link navigate={"/notes/navigation"} class="btn btn-ghost btn-sm">View Notes</.link>
      </div>
      <h1 class="text-2xl font-bold">Navigation & Routing</h1>

      <%!-- SECTION 1: Patch vs Navigate --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Patch vs Navigate</h2>
          <p class="text-sm opacity-70">
            <code>patch</code> stays in the same LiveView process (same PID, same mount time).
            <code>navigate</code> kills this process and starts a new one.
          </p>

          <%!-- Process info --%>
          <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div class="p-3 bg-base-300 rounded">
              <div class="text-xs opacity-60 uppercase tracking-wide">PID</div>
              <div class="font-mono text-sm mt-1">{@pid}</div>
            </div>
            <div class="p-3 bg-base-300 rounded">
              <div class="text-xs opacity-60 uppercase tracking-wide">Mounted At</div>
              <div class="font-mono text-sm mt-1">{@mounted_at}</div>
            </div>
            <div class="p-3 bg-base-300 rounded">
              <div class="text-xs opacity-60 uppercase tracking-wide">Render Count</div>
              <div class="font-mono text-sm mt-1">{@render_count}</div>
            </div>
          </div>

          <%!-- Patch links --%>
          <div class="mt-3">
            <h3 class="font-semibold text-sm mb-2">
              Patch Links (same process, URL changes)
            </h3>
            <div class="flex flex-wrap gap-2">
              <.link
                patch={~p"/lessons/navigation?view=list"}
                class={"btn btn-sm #{if @current_view == "list", do: "btn-primary", else: "btn-outline"}"}
              >
                ?view=list
              </.link>
              <.link
                patch={~p"/lessons/navigation?view=grid"}
                class={"btn btn-sm #{if @current_view == "grid", do: "btn-primary", else: "btn-outline"}"}
              >
                ?view=grid
              </.link>
              <.link
                patch={~p"/lessons/navigation?view=table"}
                class={"btn btn-sm #{if @current_view == "table", do: "btn-primary", else: "btn-outline"}"}
              >
                ?view=table
              </.link>
            </div>
            <div class="mt-2 p-2 bg-base-300 rounded text-sm">
              Current view: <code class="badge badge-primary badge-sm">{@current_view}</code>
              <span class="opacity-60 ml-2">
                (PID stays the same, mount time unchanged, render count increments)
              </span>
            </div>
          </div>

          <%!-- Navigate link --%>
          <div class="mt-3">
            <h3 class="font-semibold text-sm mb-2">
              Navigate Link (new process)
            </h3>
            <div class="flex flex-wrap gap-2">
              <.link navigate="/" class="btn btn-sm btn-warning">
                Navigate to Home (kills this process)
              </.link>
            </div>
            <p class="text-xs opacity-60 mt-1">
              When you navigate back, PID and mount time will be different because a new process spawns.
            </p>
          </div>

          <%!-- Visual view switching --%>
          <div class="mt-3 p-3 bg-base-300 rounded">
            <h3 class="font-semibold text-sm mb-2">
              View: {@current_view}
            </h3>
            <div :if={@current_view == "list"} class="space-y-1">
              <div class="flex items-center gap-2 text-sm">
                <span class="badge badge-ghost badge-xs">1</span> List row one
              </div>
              <div class="flex items-center gap-2 text-sm">
                <span class="badge badge-ghost badge-xs">2</span> List row two
              </div>
              <div class="flex items-center gap-2 text-sm">
                <span class="badge badge-ghost badge-xs">3</span> List row three
              </div>
            </div>
            <div :if={@current_view == "grid"} class="grid grid-cols-3 gap-2">
              <div class="p-3 bg-base-100 rounded text-center text-sm">Grid A</div>
              <div class="p-3 bg-base-100 rounded text-center text-sm">Grid B</div>
              <div class="p-3 bg-base-100 rounded text-center text-sm">Grid C</div>
            </div>
            <div :if={@current_view == "table"}>
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Col 1</th>
                    <th>Col 2</th>
                    <th>Col 3</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Table</td>
                    <td>Row</td>
                    <td>Data</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <%!-- SECTION 2: URL-Driven Filters --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">URL-Driven Filters</h2>
          <p class="text-sm opacity-70">
            The URL is the <strong>source of truth</strong>.
            <code>handle_params/3</code> reads sort and page from the query string.
            Every filter change is a <code>patch</code> that updates the URL.
          </p>

          <%!-- Sort controls --%>
          <div class="mt-3">
            <h3 class="font-semibold text-sm mb-2">Sort by:</h3>
            <div class="flex flex-wrap gap-2">
              <.link
                patch={filter_path(@current_sort, @current_page, "name")}
                class={"btn btn-sm #{if @current_sort == "name", do: "btn-primary", else: "btn-outline"}"}
              >
                Name
              </.link>
              <.link
                patch={filter_path(@current_sort, @current_page, "year")}
                class={"btn btn-sm #{if @current_sort == "year", do: "btn-primary", else: "btn-outline"}"}
              >
                Year
              </.link>
              <.link
                patch={filter_path(@current_sort, @current_page, "typing")}
                class={"btn btn-sm #{if @current_sort == "typing", do: "btn-primary", else: "btn-outline"}"}
              >
                Typing
              </.link>
            </div>
          </div>

          <%!-- Data table --%>
          <div class="overflow-x-auto mt-3">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>#</th>
                  <th>
                    Language
                    <span :if={@current_sort == "name"} class="opacity-60"> (sorted)</span>
                  </th>
                  <th>
                    Year
                    <span :if={@current_sort == "year"} class="opacity-60"> (sorted)</span>
                  </th>
                  <th>
                    Typing
                    <span :if={@current_sort == "typing"} class="opacity-60"> (sorted)</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr :for={{lang, idx} <- Enum.with_index(@filtered_languages, (@current_page - 1) * @page_size + 1)}>
                  <td class="opacity-50">{idx}</td>
                  <td class="font-semibold">{lang.name}</td>
                  <td class="font-mono">{lang.year}</td>
                  <td>
                    <span class={"badge badge-sm #{if lang.typing == "static", do: "badge-info", else: "badge-warning"}"}>
                      {lang.typing}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%!-- Pagination --%>
          <div class="mt-3 flex items-center justify-between">
            <div class="text-sm opacity-60">
              Page {@current_page} of {@total_pages}
              <span class="ml-2">
                (sort=<code>{@current_sort}</code>)
              </span>
            </div>
            <div class="join">
              <.link
                :for={page <- 1..@total_pages}
                patch={page_path(@current_sort, page)}
                class={"join-item btn btn-sm #{if page == @current_page, do: "btn-active", else: ""}"}
              >
                {page}
              </.link>
            </div>
          </div>

          <div class="mt-2 p-2 bg-base-300 rounded text-xs font-mono opacity-70">
            URL: /lessons/navigation?sort={@current_sort}&page={@current_page}
          </div>
        </div>
      </div>

      <%!-- SECTION 3: Teaching notes --%>
      <div class="card bg-info/10 border border-info/30">
        <div class="card-body text-sm space-y-2">
          <h3 class="font-bold">Key Takeaways</h3>
          <ul class="list-disc list-inside space-y-1 opacity-80">
            <li><code>&lt;.link patch=&#123;...&#125;&gt;</code> — same LiveView process, calls <code>handle_params/3</code></li>
            <li><code>&lt;.link navigate=&#123;...&#125;&gt;</code> — kills the current process, mounts a new LiveView</li>
            <li><code>handle_params/3</code> is called on mount AND on every patch</li>
            <li>Use the URL as the single source of truth for filters, sorting, pagination</li>
            <li>PID stays the same during patches; changes on navigate (new process)</li>
            <li>Query params are strings — always parse and validate with defaults</li>
            <li>Patch is faster because no mount, no new WebSocket — just a re-render</li>
            <li>Bookmarkable URLs: users can share links with filters pre-applied</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- Private helpers --

  defp sort_languages(languages, "name"), do: Enum.sort_by(languages, & &1.name)
  defp sort_languages(languages, "year"), do: Enum.sort_by(languages, & &1.year)
  defp sort_languages(languages, "typing"), do: Enum.sort_by(languages, & &1.typing)
  defp sort_languages(languages, _other), do: Enum.sort_by(languages, & &1.name)

  defp paginate(languages, page) do
    languages
    |> Enum.drop((@page_size) * (page - 1))
    |> Enum.take(@page_size)
  end

  defp total_pages do
    ceil(length(@languages) / @page_size)
  end

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(_, default), do: default

  defp filter_path(_current_sort, _current_page, new_sort) do
    ~p"/lessons/navigation?#{%{sort: new_sort, page: 1}}"
  end

  defp page_path(sort, page) do
    ~p"/lessons/navigation?#{%{sort: sort, page: page}}"
  end
end
