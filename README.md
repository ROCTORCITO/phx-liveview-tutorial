# LiveView Lab

An interactive Phoenix LiveView tutorial — 13 hands-on lessons covering architecture, state management, components, real-time features, and JavaScript interop.

## Lessons

### Foundational

| # | Lesson | Description |
|---|--------|-------------|
| 1 | **LiveView Architecture** | How LiveView works: BEAM processes, two-phase mount, WebSocket, server-rendered diffs |
| 2 | **Lifecycle Callbacks** | mount, handle_params, handle_event, handle_info, render, terminate — when and why |
| 3 | **Assigns & Reactivity** | State management with assigns, change tracking, forms, validation with to_form |
| 4 | **Events & Bindings** | phx-click, phx-change, phx-submit, debounce, throttle, keyboard events, payloads |
| 5 | **Navigation & Routing** | Patch vs navigate, handle_params, URL-driven state, live_session, query params |
| 6 | **Function Components** | Attributes, slots, slot arguments, global attrs, CoreComponents patterns |
| 7 | **Error Handling, Flash & Uploads** | Flash messages, error patterns, file uploads with live_file_input, previews |

### Advanced

| # | Lesson | Description |
|---|--------|-------------|
| 8 | **Streams & Async** | LiveView streams for efficient list rendering, async_result for non-blocking data loading |
| 9 | **Real-time Streaming** | Server-sent chunked data, token-by-token streaming UI, progress indicators |
| 10 | **Temporary Assigns & Pagination** | Memory optimization with temporary_assigns, infinite scroll, phx-update=stream |
| 11 | **LiveComponents Deep Dive** | Stateful components, lifecycle callbacks, send_update, slots & function components |
| 12 | **PubSub & Presence** | Multi-user real-time with Phoenix.PubSub, broadcast patterns, live cursors |
| 13 | **JS Hooks & Commands** | JavaScript interop, push events, JS commands, client-side state |

## Getting Started

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
* Visit [`localhost:4000`](http://localhost:4000) from your browser

Each lesson includes interactive demos and a companion notes page accessible from the lesson header.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
