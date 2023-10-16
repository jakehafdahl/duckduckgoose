defmodule CandidateActionsTest do
  use ExUnit.Case

  test "candidate with zero peers becomes goose" do
    timer1 = create_timer(:test, 10_000)
    timer2 = create_timer(:test, 10_000)
    %{mode: new_mode, election_timer: e_tmr, health_timer: h_tmr} = 
      NodeState.CandidateActions.handle_election(%{mode: :candidate, peers: [], election_timer: timer1, health_timer: timer2})

    assert e_tmr == nil
    assert new_mode == :goose
    assert  h_tmr != timer2
  end

  test "candidate getting necessary votes becomes goose" do
    timer1 = create_timer(:test, 10_000)
    timer2 = create_timer(:test, 10_000)
    state = %{mode: :candidate, peers: [1,2], election_timer: timer1, health_timer: timer2, term: 0}
    
    %{mode: new_mode, election_timer: e_tmr, term: new_term, health_timer: h_tmr} = 
      NodeState.CandidateActions.handle_election_results(1, 1, state, 1)

    assert new_mode == :goose
    assert new_term == 1
    assert h_tmr != timer2
  end

  test "candidate not getting necessary votes becomes duck" do
    timer1 = create_timer(:test, 10_000)
    timer2 = create_timer(:test, 10_000)
    state = %{mode: :candidate, peers: [1,2], election_timer: timer1, health_timer: timer2, term: 0}
    
    %{mode: new_mode, election_timer: e_tmr, term: new_term, health_timer: h_tmr} =  
      NodeState.CandidateActions.handle_election_results(0, 1, state, 1)

    assert new_mode == :duck
    assert new_term == 1
    assert e_tmr != nil
    assert e_tmr != timer1
    assert h_tmr == nil
  end

  defp create_timer(message, timeout) do
    Process.send_after(self(), message, timeout)
  end
end