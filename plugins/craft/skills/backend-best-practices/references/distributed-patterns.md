# Distributed-systems patterns: the vocabulary and when each applies

The parent skill teaches the moves (§10 idempotency, §11 resilience, §12 concurrency, §13 statelessness, §14 messaging, §15 jobs, §24 state machines). This file names the patterns those moves add up to, states the problem each solves, and the trap each carries. Use it to recognise a pattern in a codebase or a requirement and to pick one deliberately rather than by fashion. Every entry: **what → when → the trap**.

---

## 1. Consistency models — decide what "correct" means per read

- **Strong (linearizable).** Every read sees the latest committed write. What a single-primary relational database gives you *per statement* at `READ COMMITTED`. *When:* money, inventory, permissions, anything a user reads back right after writing. *Trap:* assuming it holds across replicas, caches, search indexes, or a second service — it never does. *Second trap, the inverted one:* raising isolation to `REPEATABLE READ`/`SERIALIZABLE` does **not** strengthen recency — it pins a snapshot from transaction start, so you deliberately stop seeing later commits. Stronger isolation, weaker recency (parent §2).
- **Eventual.** Replicas converge with no bound on when. What replicas, caches, search indexes, GSIs and CDC-fed stores give you. *When:* feeds, counts, analytics, search. *Trap:* read-your-own-write anomalies — the user saves, the list doesn't show it. *Fixes:* route post-write reads to the primary for a window; a session token (version/LSN) the client sends back so the server reads primary until the replica has caught up; return the written object in the write response so the UI doesn't re-read; show "pending" in the UI on purpose.
- **Monotonic reads.** A client never sees time go backwards. *Trap:* round-robin across replicas returns a newer then an older view. *Fix:* pin a session to one replica or carry a version token.
- **The consistency boundary is the aggregate.** Anything that must be atomically consistent lives in one transaction on one store (parent §2); anything across that line is eventually consistent by construction and needs a pattern from §2–§4 below. Draw the boundary on purpose.
- **CAP is a constraint under partitions, not a menu.** During a network partition each operation chooses availability or consistency; the rest of the time the trade is latency vs consistency (PACELC). State the choice per operation, not per system.

---

## 2. Sagas — a transaction across services, done as a sequence with undo

- **What.** A multi-step business operation where each step commits locally and has a compensating action that semantically undoes it (refund, release hold, cancel shipment). No global lock, no two-phase commit.
- **Orchestration.** One coordinator — a workflow engine, a state-machine row, a durable function — drives steps and compensations. Explicit, debuggable, one place to answer "where is order 123 stuck?" Prefer it past three steps or whenever humans will ask that question.
- **Choreography.** Each service reacts to events and emits the next. Loosely coupled, no coordinator, and after five services nobody can draw the flow. Two or three steps at most.
- **Rules.** Every step idempotent (parent §10). Every compensation idempotent and safe to run twice or out of order. Saga state persisted *before* each call so a crash resumes (parent §24). A **pivot** step after which you stop compensating and only retry forward (money captured → go forward, never back). Time-box the saga and alert on stuck ones.
- **Trap: sagas are not isolated.** Another request can see the intermediate state (reserved-but-unpaid). Model it explicitly (`reserved`, `pending_payment`) rather than hiding it, and use a semantic lock — a status that means "in flight" — where a concurrent action would be wrong.
- **2PC / XA.** A coordinator holds locks on every participant until all vote: blocking, slow, and the coordinator is a single point of failure. Inside a *distributed database* that owns all of its shards it is an implementation detail and fine; across independent services and stores, use sagas plus the outbox.

---

## 3. Outbox, inbox, and the exactly-once myth

- **Outbox** (parent §14). Write the event in the same transaction as the state change; a relay publishes committed rows. Solves "committed but never published."
- **Inbox / idempotent consumer.** Store processed message ids under a unique constraint *in the same transaction* as the handler's effects; a redelivery hits the constraint and is dropped. Solves at-least-once delivery. Keep ids at least as long as the broker can redeliver.
- **CDC** (log tailing). The outbox without the table — the database's replication log is the event stream. *Trap:* it publishes your table shape as your public event schema; put a translation step in front.
- **"Exactly-once delivery"** is at best exactly-once *processing inside the broker's own transactions*. Across your database and the broker, idempotency is the mechanism. Design for duplicates and you never need the guarantee.
- **Event schema evolution.** Events are a contract with consumers you haven't met: additive changes only; a new event type or version when semantics change (`OrderPlaced.v2`); old versions stay consumable (upcasters); never reuse a field with a new meaning.

---

## 4. CQRS, read models, event sourcing

- **CQRS.** Separate the write model (normalized, validated, transactional) from read models (denormalized, shaped per screen). Justified when reads and writes differ in shape or scale; not justified by itself.
- **Read models / projections** are derived stores (`datastore-antipatterns.md` §0): rebuildable from the source, eventually consistent, disposable. Every projection needs a rebuild path and a lag metric.
- **Materialized views and precomputed aggregates** are the single-database version of the same idea: refreshed on a schedule or on write, with known staleness.
- **Event sourcing.** The event log *is* the state; current state is a fold over events. *When:* full history is a first-class requirement, or temporal queries ("what did the account look like on Tuesday?"). *Traps:* every read is a replay unless you snapshot; old event schemas live forever; any query not "by aggregate id" needs a projection anyway; erasure (GDPR) fights the immutable log. A `status` column plus an append-only events table (parent §24) gives most teams the audit trail without the operating cost.

---

## 5. Resilience patterns, named

Parent §11 and §16 give the rules; these are the components and their states.

- **Timeout.** The budget for one call, derived from the caller's remaining deadline and propagated (gRPC deadline, header, context). Per dependency, never global.
- **Retry with exponential backoff and jitter.** Transient errors, idempotent operations only; cap attempts *and* total time; a retry budget (≤10% extra load) so retries can't become the outage.
- **Circuit breaker.** Per dependency, three states: **closed** (normal; count failures and slow calls over a window), **open** (fail fast for a cooldown, no calls), **half-open** (a trickle through; close on success, reopen on failure). *Trap:* one breaker for all of a dependency's endpoints — a broken write path trips reads too; scope by dependency *and* operation class. Every open breaker has a defined fallback: cached, default, degraded, or a clean `503`.
- **Bulkhead.** Separate pools, queues or threads per dependency or tenant so one saturated dependency can't take every worker. *Trap:* pools so small the bulkhead is the bottleneck under normal load.
- **Load shedding / admission control.** Reject early (`429`/`503` plus `Retry-After`) when a bounded queue is full or a concurrency limit is hit; shed low-priority traffic first. Adaptive limits (AIMD/gradient) find the ceiling for you.
- **Fallback / graceful degradation.** A defined lesser answer for an *optional* dependency: stale cache, default, feature hidden. Decide per dependency which are required and which are optional.
- **Hedged requests.** For idempotent reads with a long tail, send a second request to another replica once the first has waited past the p95 and take whichever answers first. *Trap:* doubles load if mis-tuned; reads only, with a budget.
- **Rate limiting.** Token bucket or sliding window per key at the edge (parent §18). Policy, not self-defence — shedding is self-defence.

---

## 6. Coordination — leases, fencing, and the lock that isn't

- **Leader lease** (parent §15, §25). One instance holds a lease with a TTL and renews it; when it dies the lease expires and another takes over.
- **Fencing tokens.** A lease alone isn't safe: a paused holder can wake after expiry and keep writing. Each grant carries a monotonically increasing token; every write includes it and the store rejects tokens older than the latest it has seen (`WHERE lease_epoch = $1`). Without fencing, "exactly one leader" is a hope.
- **Distributed locks** (parent §12; `datastore-antipatterns.md` §2 Coordination). Coordination and dedup, never correctness. The invariant lives in the database: unique constraint, atomic conditional update.
- **Consensus systems** (etcd, ZooKeeper, Consul; Postgres advisory locks for the small case). Use one that exists. Never write your own.

---

## 7. Partitioning, replication, and the queue as a system

- **Sharding.** Pick the partition key from the access pattern (`datastore-antipatterns.md` §4): high cardinality, even spread, present in every hot query. *Traps:* cross-shard queries and joins (scatter-gather, slow, no transactions); resharding later (design the key space for it: hash plus virtual buckets); hot keys (one whale tenant).
- **Replication.** Synchronous replicas cost write latency and buy durability (RPO ≈ 0); asynchronous replicas are fast and lose the tail on failover. Know your RPO/RTO, test failover, route reads deliberately (read-your-writes → primary).
- **Split-brain.** Two nodes both believe they are primary. Prevention is fencing plus quorum election, not a timeout.
- **Queues as a system** (parent §14, §15). At-least-once; ordered only per key/partition; consumer groups scale consumers; DLQ for poison; backpressure via bounded prefetch. Queue depth is latency: by Little's law a queue that keeps growing is an outage nobody has noticed yet.
- **Visibility-timeout brokers (SQS, RabbitMQ).** The timeout *is* the lease: a message whose lease expires before the consumer acks is redelivered to someone else. Size it above the slowest realistic processing time, extend it for long work, and make the handler idempotent because redelivery is normal, not exceptional.
- **Kafka is not a visibility-timeout broker, and its failure mode is different in kind.** Ordering is per *partition*, and a key maps to a partition by `hash(key) % partitions` — so **adding partitions permanently breaks per-key ordering for existing keys**, because the same key now hashes elsewhere while its old records stay put. Size the topic up front or migrate to a new one. Offsets, not acks: commit **after** processing for at-least-once; auto-commit will advance past records you never finished. A consumer that exceeds `max.poll.interval.ms` (default 300000) is *evicted from the group* and its partitions reassigned, so slow processing surfaces as a rebalance loop plus commit failures, never as a single redelivery. And **dead-lettering a record breaks ordering for that key** — a later record gets processed while an earlier one sits in the DLQ; decide explicitly whether that key's stream may skip ahead, or halt the partition instead.

---

## 8. Time in a distributed system

- **Wall clocks disagree.** NTP skew runs milliseconds to seconds; VMs pause. Never order events across nodes by timestamp, never expire a lease by comparing another node's clock, never compute one duration from two services' `now()`.
- **Monotonic clocks** for durations and timeouts inside a process. **Logical versions** — a sequence, a version column, an LSN, a Lamport or vector clock when you truly need it — for ordering across nodes.
- **The server assigns time.** `created_at` is the server's clock at commit, never the client's. Idempotency windows, token expiries and SLAs are computed server-side and stored as absolute UTC (`timestamptz`).

---

## 9. Service boundaries — the shape that makes the rest possible

- **A service owns its data.** No other service reads or writes its tables; integration is API or events. A shared database is a distributed monolith with added latency.
- **Sync vs async.** Call synchronously when the caller needs the answer to respond; publish an event when it doesn't. A chain of synchronous calls multiplies p99s and couples availability (parent §11; `latency-and-locks.md` §1).
- **Bounded contexts.** Split along business language and rate of change, not along nouns or the org chart. A boundary is where a term changes meaning ("customer" in billing vs support).
- **Anti-corruption layer.** Translate a legacy or third-party model at the boundary so its shape doesn't leak into yours. **Strangler fig.** Route one slice of traffic to the new implementation behind a facade, expand slice by slice, retire the old — never a big-bang rewrite.
- **Contract tests** (parent §22) are how independent deployability survives: each side verifies against the agreed schema in CI.

---

## 10. Caching patterns, named (parent §17)

- **Cache-aside.** App checks cache, misses, reads DB, writes cache. Simple, tolerant of cache loss. *Traps:* stampede on hot-key expiry (single-flight) and stale reads until TTL.
- **Read-through.** The cache loads on miss itself; same semantics, less duplicated code.
- **Write-through.** Write DB and cache together: fresh reads, slower writes. **Write-behind.** Write cache, flush to DB later: fastest writes and *data loss on cache failure* — only for data you can afford to lose.
- **Negative caching.** Cache "not found" briefly so a missing key can't be used to hammer the database.
- **Warming.** Prime hot keys before traffic arrives (deploy, cache restart) or the first minute is a stampede.
- **Invalidation.** TTL is the floor, explicit bust on write is the ceiling, versioned keys make both safe (parent §17).
