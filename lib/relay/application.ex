defmodule Relay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RelayWeb.Telemetry,
      Relay.Redis,
      Relay.Repo,
      {DNSCluster, query: Application.get_env(:relay, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Relay.PubSub},
      RelayWeb.Presence,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Relay.Finch},
      # Start a worker by calling: Relay.Worker.start_link(arg)
      # {Relay.Worker, arg},
      # Start to serve requests, typically the last entry
      RelayWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Relay.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RelayWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
