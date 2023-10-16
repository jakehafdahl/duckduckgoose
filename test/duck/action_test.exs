defmodule DuckActionsTest do
  use ExUnit.Case

  test "duck receving election timeout becomes candidate" do
    %{mode: new_mode, election_timer: e_tmr, health_timer: h_tmr} = 
      NodeState.DuckActions.handle_election(%{mode: :candidate, peers: [], election_timer: nil, health_timer: nil})

    assert new_mode == :candidate
    assert e_tmr != nil
    assert h_tmr == nil
  end

  test "duck responding to request vote of higher term grants vote and updates state" do
    state = %{mode: :duck, election_timer: nil, health_timer: nil, term: 0}

    [%{"vote_granted" => granted, "term" => response_term}, %{term: new_term}] = NodeState.DuckActions.handle_request_vote(state, 1)

    assert granted == true
    assert new_term == 1
    assert new_term == response_term
  end

  test "duck responding to request vote of lower term does not grant vote" do
    state = %{mode: :duck, election_timer: nil, health_timer: nil, term: 2}

    [%{"vote_granted" => granted, "term" => response_term}, %{term: new_term}] = NodeState.DuckActions.handle_request_vote(state, 1)

    assert granted == false
    assert new_term == 2
    assert new_term == response_term
  end

  test "duck responding to healthcheck resets election timer" do
    timer1 = create_timer(:test, 10_000)
    peers = [1,2,3]
    state = %{mode: :duck, election_timer: timer1, peers: peers, term: 0}
    info = %{term: 1, peers: peers}

    [_reply, %{mode: new_mode, election_timer: e_tmr, peers: new_peers, term: new_term}] = NodeState.DuckActions.handle_healthcheck(info, state)

    assert new_mode == :duck
    assert e_tmr != nil
    assert e_tmr != timer1
    assert new_peers == peers
    assert new_term == 1
  end

  defp create_timer(message, timeout) do
    Process.send_after(self(), message, timeout)
  end
end
