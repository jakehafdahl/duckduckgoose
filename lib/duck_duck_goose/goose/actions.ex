defmodule NodeState.GooseActions do
  require Logger

  def poll_duck(duck, %{term: term, peers: peers, port: port}) do
    Logger.info("Polling http://#{duck}/poll with #{Poison.encode!(%{term: term, peers: peers})}")
    headers = [{"Content-type", "application/json"}]

    duck_peers = peers -- [duck]

    {_, resp} = HTTPoison.post("http://#{duck}/poll", Poison.encode!(%{"term" => term, "peers" => duck_peers ++ ["localhost:#{port}"]}), headers, [] )
    Logger.info("resp is #{inspect(resp)}")
    case resp do
      %HTTPoison.Response{status_code: 200, body: body} -> 
        %{"term" => new_term} = Poison.decode!(body)
        {:ok, new_term}
      _               -> {:ok, term}
    end
  end

  def handle_healthcheck(%{ term: new_term}, %{term: term} = current_state) when new_term >= term do
    new_state = NodeState.DuckActions.become_duck(current_state)

    [%{term: new_term}, new_state]
  end

  def handle_healthcheck(_data, %{term: term} = current_state) do
    [%{term: term}, current_state]
  end

  def become_goose(%{health_timer: h_tmr, election_timer: e_tmr} = state) do
    Logger.info("Becoming a goose #{inspect(state)}")
    
    if e_tmr != nil do
      Process.cancel_timer(e_tmr, async: true, info: false)
    end

    if h_tmr != nil do
      Process.cancel_timer(h_tmr, async: true, info: false)
    end

    health_timer = schedule_poll_ducks()
    %{state | mode: :goose, health_timer: health_timer, election_timer: nil}
  end

  def handle_election(state) do
    become_goose(state)
  end

  def handle_request_vote(%{term: current_term} = state, new_term) do
    cond do
      current_term < new_term -> 
        [%{"vote_granted" => true, "term" => new_term}, NodeState.DuckActions.become_duck(%{state | term: Enum.max([current_term, new_term])})]
      true -> [%{"vote_granted" => false, "term" => current_term}, state]
    end
  end

  def handle_poll_ducks(%{peers: []} = state) do
    Logger.info("No ducks to poll, stay the goose")
    health_timer = schedule_poll_ducks()
    %{state | health_timer: health_timer}
  end

  def handle_poll_ducks(%{peers: ducks, term: current_term} = state) do
    Logger.info("Polling ducks")
    max_term = ducks
    |> Enum.map(fn duck -> NodeState.GooseActions.poll_duck(duck, state) end)
    |> Enum.map(fn resp -> elem(resp, 1) end)
    |> Enum.max()

    cond do
      max_term > current_term ->
        NodeState.DuckActions.become_duck(%{state | term: max_term})
      true ->
        health_timer = schedule_poll_ducks()
        %{state | health_timer: health_timer, term: current_term}
    end
  end

  defp schedule_poll_ducks() do
    Process.send_after(self(), :poll_ducks, 2_000)
  end
end