defmodule DuckDuckGoose.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    children = 
      Application.get_env(:duckduckgoose, :environment)
      |> children()

    opts = [strategy: :one_for_one, name: NodeState.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children(:test) do
    []
  end

  defp children(_) do
    {port, _} = Integer.parse(System.get_env("DUCK_PORT") || "4000")
    join_node = System.get_env("DUCK_JOIN")

    peers = case join_node do
      nil -> []
      _ -> [join_node]
    end

    Logger.info("starting server with peers #{inspect(join_node)}")

    [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: NodeState.Endpoint,
        options: [port: port]
      ),
      %{
        id: NodeState.Server ,
        start: {NodeState.Server , :start_link, [%{peers: peers, port: port}]}
      }
    ]
  end
end
