defmodule NodeState.Server do
  use GenServer
  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def add_peer(address) do
    GenServer.call(__MODULE__, {:add_peer, address})
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def health_check(msg) do
    GenServer.call(__MODULE__, {:health_check, msg})
  end

  def request_vote(term) do
    GenServer.call(__MODULE__, {:request_vote, term})
  end

  def init(%{peers: [], port: port} = data) do
    Logger.info("Starting #{__MODULE__}.init with args #{inspect(data)}")
    state = NodeState.DuckActions.become_duck(%{ mode: :duck, election_timer: nil, health_timer: nil, term: 0, peers: [], port: port})
    {:ok, state}
  end

  def init(%{peers: [master] = peers, port: port} = data) do
    Logger.info("Starting #{__MODULE__}.init with args #{inspect(data)}")
    NodeState.DuckActions.join_node(master, port)
    state = NodeState.DuckActions.become_duck(%{ mode: :duck, election_timer: nil, health_timer: nil, term: 0, peers: peers, port: port})
    {:ok, state}
  end

  def handle_info(:election, %{mode: :duck} = state) do
    Logger.info("Election Timeout duck")
    new_state = NodeState.DuckActions.handle_election(state)

    {:noreply, new_state}
  end

  def handle_info(:election, %{mode: :candidate} = state) do
    Logger.info("Election Timeout candidate")
    new_state = NodeState.CandidateActions.handle_election(state)

    {:noreply, new_state}
  end

  def handle_info(:election, %{mode: :goose} = state) do
    Logger.info("Election Timeout goose, this should not happen")
    new_state = NodeState.GooseActions.handle_election(state)

    {:noreply, new_state}
  end

  def handle_info(:poll_ducks, %{mode: :goose} = state) do
    new_state = NodeState.GooseActions.handle_poll_ducks(state)
    {:noreply, new_state}
  end

  def handle_info(:poll_ducks, %{mode: :duck} = state) do
    new_state = NodeState.DuckActions.become_duck(state)
    {:noreply, new_state}
  end

    def handle_info(:poll_ducks, %{mode: :candidate} = state) do
    new_state = NodeState.DuckActions.become_duck(state)
    {:noreply, new_state}
  end

  def handle_call({:request_vote, term}, _from, %{mode: :goose} = state) do
    [reply, new_state] = NodeState.GooseActions.handle_request_vote(state, term)

    {:reply, reply, new_state}
  end

  def handle_call({:request_vote, term}, _from, %{mode: :duck} = state) do
    [reply, new_state] = NodeState.DuckActions.handle_request_vote(state, term)

    {:reply, reply, new_state}
  end

  def handle_call({:request_vote, term}, _from, %{mode: :candidate} = state) do
    [reply, new_state] = NodeState.CandidateActions.handle_request_vote(state, term)

    {:reply, reply, new_state}
  end

  def handle_call({:health_check, data}, _from, %{mode: :duck} = current_state) do
    [reply, new_state] = NodeState.DuckActions.handle_healthcheck(data, current_state)

    {:reply, reply, new_state}
  end

  def handle_call({:health_check, data}, _from, %{mode: :goose} = current_state) do
    Logger.info("Handling goose health check")
    [reply, new_state] = NodeState.GooseActions.handle_healthcheck(data, current_state)

    {:reply, reply, new_state}
  end

  def handle_call({:add_peer, peer}, _from, %{peers: peers} = current_state) do
    list = [peer | peers]

    {:reply, :ok, %{current_state | peers: Enum.uniq(list)}}
  end

  def handle_call(:get_state, _from, %{mode: mode, peers: peers} = state) do

    response_mode = case mode do
      :goose -> :goose
      _ -> :duck
    end

    {:reply, %{mode: response_mode, peers: peers}, state}
  end
end