defmodule MindreCash.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Add your supervised processes here
      {Plug.Cowboy, scheme: :http, plug: MindreCash.SimpleServer, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: MindreCash.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
