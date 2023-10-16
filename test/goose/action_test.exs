defmodule GooseActionsTest do
  use ExUnit.Case


  test "handle election message for goose cancels election timer and does state cleanup" do
     timer1 = create_timer(:test, 10_000)
     timer2 = create_timer(:test, 10_000)
     state = %{mode: :goose, election_timer: timer1, health_timer: timer2, term: 0}

     %{mode: new_mode, election_timer: e_tmr, health_timer: h_tmr} = NodeState.GooseActions.handle_election(state)

     assert new_mode == :goose
     assert e_tmr == nil
     assert h_tmr != nil
     assert h_tmr != timer2
  end

  test "handle poll ducks, no ducks" do
     timer1 = create_timer(:test, 10_000)
     state = %{mode: :goose, election_timer: nil, health_timer: timer1, term: 0, peers: []}

     %{election_timer: e_tmr, health_timer: h_tmr} = NodeState.GooseActions.handle_poll_ducks(state)

     assert e_tmr == nil
     assert h_tmr != nil
     assert h_tmr != timer1
  end

    defp create_timer(message, timeout) do
    Process.send_after(self(), message, timeout)
  end

end
