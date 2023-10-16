defmodule NodeState.Endpoint do
  use Plug.Router
  require Logger

  # This module is a Plug, that also implements it's own plug pipeline, below:

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  get "/ping" do
    send_resp(conn, 200, "pong!")
  end

  get "/status" do
    state = NodeState.Server.get_state()
    send_resp(conn, 200, Poison.encode!(state))
  end

  get "/joincluster/:host" do
    {status, body} =
      case conn.params do
        %{"host" => host} -> {200, add_node(host)}
        _ -> {422, "{}"}
      end

    send_resp(conn, status, body)
  end

  post "/poll" do
    Logger.info("received healthcheck #{inspect(conn.body_params)}")
    {status, body} =
      case conn.body_params do
        %{"term" => term, "peers" => peers} -> {200, healthcheck(%{term: term, peers: peers})}
        _ -> {422, "ERROR missing properties"}
      end


    send_resp(conn, status, body)
  end


  post "/request_vote" do
    Logger.info("received request_vote #{inspect(conn.body_params)}")
    {status, body} =
      case conn.body_params do
        %{"term" => term} -> {200, request_vote(term)}
        _ -> {422, "ERROR missing properties"}
      end


    send_resp(conn, status, body)
  end

  defp add_node(address) do
    NodeState.Server.add_peer(address)
    Poison.encode!(%{response: "Received joincluster for #{address}!"})
  end

  defp healthcheck(msg) do
    Poison.encode!(NodeState.Server.health_check(msg))
  end

  defp request_vote(term) do
    response = NodeState.Server.request_vote(term)
    Logger.info("request vote response is #{inspect(response)}")
    Poison.encode!(response)
  end

  # A catchall route, 'match' will match no matter the request method,
  # so a response is always returned, even if there is no route to match.
  match _ do
    send_resp(conn, 404, "oops... Nothing here :(")
  end
end