defmodule LiveviewLab.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveviewLabWeb.Telemetry,
      LiveviewLab.Repo,
      {DNSCluster, query: Application.get_env(:liveview_lab, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveviewLab.PubSub},
      # Start a worker by calling: LiveviewLab.Worker.start_link(arg)
      # {LiveviewLab.Worker, arg},
      # Start to serve requests, typically the last entry
      LiveviewLabWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveviewLab.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveviewLabWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
