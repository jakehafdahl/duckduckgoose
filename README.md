# DuckDuckGoose

This project is a simple implementation of a node in a DuckDuckGoose cluster. After reading the description it is clear that this is a consensus algorithm in which we're electing a goose (leader). The interesting parts of the problem lie in the leader election so I opted not to use a library to implement this as I would have normally if this were for an actual work project (https://github.com/elixir-toniq/raft). I also researched a couple other consensus protocols but found them to have drawbacks to this particular problem ([Bully Algorithm](https://en.wikipedia.org/wiki/Bully_algorithm) could cause a lot of churn if there were an unhealthy host with a high process id). I also looked at Paxos but it semed too complex to complete in a small amount of time.

The benefits of Raft were that it is highly consistent (at the expense of availability in small clusters, this is minimized with higher number of nodes) which satisfies the single goose requirement. It is also partition tolerant as a second goose will not be election if there is not enough consensus and which the connection is re-established there will be a reconciliation of geese in the event a goose was partitioned from the rest of the cluster.


## Implementation
I implemented this by roughly following the below state machine definition
![RAFT description](https://eli.thegreenplace.net/images/2020/raft-highlevel-state-machine.png)

I also made the goose able to add nodes elastically on startup with the DUCK_JOIN environment variable

## Decisions
Left out of scope:
- peristing state outside of genserver for recovery post crash
- ability to remove a node from a cluster

Other decisions
- Purposly did not use erlang nodes and clusters in order to be language agnostic

## Running 
The below three lines will start 3 servers (in three different consoles)
Give the first node about 10 seconds to start before starting the others to avoid
startup churn and elections (it will handle this, but it makes startup take longer)
```
DUCK_PORT=4001 iex -S mix

DUCK_PORT=4002 DUCK_JOIN=localhost:4001 iex -S mix

DUCK_PORT=4003 DUCK_JOIN=localhost:4001 iex -S mix
```

and you can check on the state of the node using the `localhost:<port>/status`

Once the cluster is up and running kill any of the nodes in the terminal to watch leader elections take place, you can continue to add nodes as well using the environment variables `DUCK_PORT` and `DUCK_JOIN` (Note: you must join the goose node).
