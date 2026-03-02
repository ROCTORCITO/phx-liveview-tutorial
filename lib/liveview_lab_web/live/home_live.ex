defmodule LiveviewLabWeb.HomeLive do
  use LiveviewLabWeb, :live_view

  @lessons [
    # Foundational (1-7)
    %{
      path: "/lessons/architecture",
      title: "LiveView Architecture",
      desc: "How LiveView works: BEAM processes, two-phase mount, WebSocket, server-rendered diffs",
      tag: "Architecture"
    },
    %{
      path: "/lessons/lifecycle",
      title: "Lifecycle Callbacks",
      desc: "mount, handle_params, handle_event, handle_info, render, terminate — when and why",
      tag: "Lifecycle"
    },
    %{
      path: "/lessons/assigns-reactivity",
      title: "Assigns & Reactivity",
      desc: "State management with assigns, change tracking, forms, validation with to_form",
      tag: "State"
    },
    %{
      path: "/lessons/events",
      title: "Events & Bindings",
      desc: "phx-click, phx-change, phx-submit, debounce, throttle, keyboard events, payloads",
      tag: "Events"
    },
    %{
      path: "/lessons/navigation",
      title: "Navigation & Routing",
      desc: "Patch vs navigate, handle_params, URL-driven state, live_session, query params",
      tag: "Navigation"
    },
    %{
      path: "/lessons/function-components",
      title: "Function Components",
      desc: "Attributes, slots, slot arguments, global attrs, CoreComponents patterns",
      tag: "Components"
    },
    %{
      path: "/lessons/error-handling",
      title: "Error Handling, Flash & Uploads",
      desc: "Flash messages, error patterns, file uploads with live_file_input, previews",
      tag: "Practical"
    },
    # Advanced (8-13)
    %{
      path: "/lessons/streams",
      title: "Streams & Async",
      desc: "LiveView streams for efficient list rendering, async_result for non-blocking data loading",
      tag: "Performance"
    },
    %{
      path: "/lessons/streaming",
      title: "Real-time Streaming",
      desc: "Server-sent chunked data, token-by-token streaming UI, progress indicators",
      tag: "Streaming"
    },
    %{
      path: "/lessons/temporary-assigns",
      title: "Temporary Assigns & Pagination",
      desc: "Memory optimization with temporary_assigns, infinite scroll, phx-update=stream",
      tag: "Performance"
    },
    %{
      path: "/lessons/components",
      title: "LiveComponents Deep Dive",
      desc: "Stateful components, lifecycle callbacks, send_update, slots & function components",
      tag: "Components"
    },
    %{
      path: "/lessons/pubsub",
      title: "PubSub & Presence",
      desc: "Multi-user real-time with Phoenix.PubSub, broadcast patterns, live cursors",
      tag: "Real-time"
    },
    %{
      path: "/lessons/js-hooks",
      title: "JS Hooks & Commands",
      desc: "JavaScript interop, push events, JS commands, client-side state",
      tag: "Interop"
    }
  ]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, lessons: @lessons, page_title: "LiveView Lab")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="text-center space-y-4">
        <h1 class="text-4xl font-bold">LiveView Lab</h1>
        <p class="text-lg opacity-70 max-w-xl mx-auto">
          Phoenix LiveView from foundations to advanced patterns — architecture,
          lifecycle, state, components, real-time, and JavaScript interop.
        </p>
      </div>

      <div class="grid gap-4">
        <.link
          :for={{lesson, idx} <- Enum.with_index(@lessons, 1)}
          navigate={lesson.path}
          class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
        >
          <div class="card-body p-4">
            <div class="flex items-start gap-3">
              <span class="badge badge-neutral font-mono">{idx}</span>
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <h2 class="card-title text-base">{lesson.title}</h2>
                  <span class="badge badge-sm badge-outline">{lesson.tag}</span>
                </div>
                <p class="text-sm opacity-70 mt-1">{lesson.desc}</p>
              </div>
              <span class="text-lg opacity-50">→</span>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
