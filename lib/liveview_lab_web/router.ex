defmodule LiveviewLabWeb.Router do
  use LiveviewLabWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveviewLabWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveviewLabWeb do
    pipe_through :browser

    live "/", HomeLive

    # Foundational lessons (1-7)
    live "/lessons/architecture", Lesson1ArchitectureLive
    live "/lessons/lifecycle", Lesson2LifecycleLive
    live "/lessons/assigns-reactivity", Lesson3AssignsReactivityLive
    live "/lessons/events", Lesson4EventsLive
    live "/lessons/navigation", Lesson5NavigationLive
    live "/lessons/function-components", Lesson6FunctionComponentsLive
    live "/lessons/error-handling", Lesson7ErrorHandlingLive

    # Advanced lessons (8-13)
    live "/lessons/streams", Lesson8StreamsLive
    live "/lessons/streaming", Lesson9StreamingLive
    live "/lessons/temporary-assigns", Lesson10TempAssignsLive
    live "/lessons/components", Lesson11ComponentsLive
    live "/lessons/pubsub", Lesson12PubsubLive
    live "/lessons/js-hooks", Lesson13JsHooksLive

    live "/notes/:lesson", NotesLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveviewLabWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:liveview_lab, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveviewLabWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
