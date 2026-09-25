defmodule OpenInterclubs.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OpenInterclubsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:openinterclubs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OpenInterclubs.PubSub},
      OpenInterclubs.Kbsb.Cache,
      {OpenInterclubs.Season,
       autoload: Application.get_env(:openinterclubs, :season_autoload, true)},
      # Start to serve requests, typically the last entry
      OpenInterclubsWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpenInterclubs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OpenInterclubsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
