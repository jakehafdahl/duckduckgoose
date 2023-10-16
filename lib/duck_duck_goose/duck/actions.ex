defmodule NodeState.DuckActions do
  require Logger
  

  def handle_healthcheck(%{ term: new_term, peers: peers}, %{election_timer: timer_pid} = current_state) do
    Process.cancel_timer(timer_pid, async: true, info: false)
    election_timer = schedule_info(:election)

    [%{term: new_term}, %{current_state | mode: :duck, election_timer: election_timer, term: new_term, peers: peers}]
  end

  def handle_election(state) do
    election_timer = schedule_info(:election)
    
    %{state | mode: :candidate, election_timer: election_timer}
  end

  def handle_request_vote(%{term: current_term} = state, new_term) do
    cond do
      current_term < new_term -> 
        [%{"vote_granted" => true, "term" => new_term}, NodeState.DuckActions.become_duck(%{state | term: Enum.max([current_term, new_term])})]
      true -> [%{"vote_granted" => false, "term" => current_term}, state]
    end
  end

  def start_election(%{peers: [], term: term} = state) do
    Logger.info("Starting election for term #{term} with no peers, become the goose!")
    # Call all peers with a request for vote and your current term
      health_timer = Process.send_after(self(), :poll_ducks, 2_000)
    %{ state | mode: :goose, health_timer: health_timer }
  end

  def become_duck(%{health_timer: h_tmr, election_timer: e_tmr} = state) do
    Logger.info("Becoming a duck #{inspect(state)}")
    
    if e_tmr != nil do
      Process.cancel_timer(e_tmr, async: true, info: false)
    end

    if h_tmr != nil do
      Process.cancel_timer(h_tmr, async: true, info: false)
    end

    election_timer = schedule_info(:election)
    %{state | mode: :duck, health_timer: nil, election_timer: election_timer}
  end

  def join_node(goose, port) do
    Logger.info("http://#{goose}/joincluster/localhost:#{port}")
    resp = case HTTPoison.get("http://#{goose}/joincluster/localhost:#{port}") do
      {:ok, %{status_code: 200, body: body}} ->
        Poison.decode!(body)
    end

    Logger.info("called status #{inspect(resp)}")
  end

  defp schedule_info(message) do
    random_number = :rand.uniform(2) * 100
    Process.send_after(self(), message, 5_000 + random_number)
  end

end