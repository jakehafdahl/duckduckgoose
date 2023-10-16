defmodule NodeState.CandidateActions do
  require Logger

  def handle_election(%{peers: []} = state) do
    Logger.info("peer is empty, become goose!")
    NodeState.GooseActions.become_goose(state)
  end

  def handle_election(%{peers: peers, term: term, election_timer: election_timer} = state) do
    next_term = term + 1
    Logger.info("Starting election for term #{next_term}")

    # # Call all peers with a request for vote and your current term
    quorum_value = Enum.count(peers) / 2

    if election_timer != nil do
      Process.cancel_timer(election_timer)
    end

    results = peers
    |> Enum.map(fn peer -> call_peer(peer, state)
    end)
    
    votes = results |> Enum.count(fn %{vote_granted: grant_val} -> grant_val == true end)
    max_term = cond do
      length(results) > 1 -> Enum.max_by(results, fn %{term: term} -> term end)
      true -> Enum.at(results, 0)
    end

    %{term: max_term_number} = max_term

    handle_election_results(votes, quorum_value, state, Enum.max([max_term_number, next_term]))
  end

  def handle_election_results(votes, quorum_value, state, new_term) do
    cond do
      votes >= quorum_value -> 
        Logger.info("votes received #{votes}, become goose!")
        NodeState.GooseActions.become_goose(%{state | term: new_term})
      true ->
        NodeState.DuckActions.become_duck(%{state | term: new_term})
    end
  end

  def handle_request_vote(%{term: current_term} = state, new_term) do
    cond do
      current_term < new_term -> 
        [%{"vote_granted" => true, "term" => new_term}, NodeState.DuckActions.become_duck(%{state | term: Enum.max([current_term, new_term])})]
      true -> [%{"vote_granted" => false, "term" => current_term}, state]
    end
  end

  def call_peer(duck, %{term: term} = _data) do
    headers = [{"Content-type", "application/json"}]
    {_, resp} = HTTPoison.post("http://#{duck}/request_vote", Poison.encode!(%{"term" => term + 1}), headers, [] )

    Logger.info("resp is #{inspect(resp)}")
    case resp do
      %HTTPoison.Response{status_code: 200, body: body} -> 
        %{"vote_granted" => granted, "term" => new_term} = Poison.decode!(body)
        %{vote_granted: granted, term: new_term}
      _ -> %{vote_granted: false, term: term}
    end
  end
end