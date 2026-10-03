# Distributed and cross-service patterns

Patterns for when the problem crosses a process, service, or machine boundary. Everything here exists because of one fact: **a call across a boundary can fail in a way where you don't learn the outcome.** A timeout is not a failure — it's an unknown. Nearly every pattern below is a response to that.

**Scope of this file.** It decides *which* pattern fits, and names the trade. For the runtime mechanics of executing one safely — transaction boundaries and isolation, lock behaviour, retry policy, connection pooling, running a migration without locking production — `backend-best-practices` goes deeper and should lead once the pattern is chosen. Come here for the choice, go there for the implementation.

## Contents

- [Choosing by symptom](#choosing-by-symptom)
- [Consistency across services](#consistency-across-services)
- [Surviving partial failure](#surviving-partial-failure)
- [Reading and writing at scale](#reading-and-writing-at-scale)
- [Coordination](#coordination)
- [Evolving a system](#evolving-a-system)

## Choosing by symptom

| Symptom | Reach for |
|---|---|
| A business operation spans services and must not half-complete | saga with compensations |
| Wrote to the DB, then publishing the event failed — now they disagree | outbox |
| The same webhook or message arrives twice and double-applies | inbox + idempotency key |
| A retried `POST` charged the customer twice | idempotency key |
| One failing dependency is taking the whole service down | circuit breaker + bulkhead + timeouts |
| Reads and writes have wildly different shapes and volumes | CQRS with a read model |
| "What was the state on the 3rd?" is unanswerable | event sourcing, or an append-only audit log |
| Tail latency is dominated by one slow replica | hedged requests |
| A scheduled job runs N times on N replicas | leader election with a lease |
| A paused node woke up and wrote stale data | fencing token |
| One tenant's traffic is saturating one shard | re-key the partition |
| A legacy monolith must be replaced without a rewrite | strangler fig |
| A third-party model is leaking into your domain | anti-corruption layer |
| Three clients each need a different shape of the same data | backend-for-frontend |

## Consistency across services

**Saga.** A business transaction spanning services, done as a sequence of local transactions where each has a **compensating action** that undoes it. There is no distributed transaction to roll back, so you go forward with explicit undo instead.

Two shapes:
- **Orchestration** — one coordinator tells each service what to do and drives compensation. Easier to understand and debug, because the whole flow reads in one place. The coordinator is a component you must build and keep available.
- **Choreography** — each service reacts to events from the others; no central brain. Fewer moving parts, more decoupled, but the end-to-end flow exists nowhere and is correspondingly hard to reason about or debug.

*Decide by asking:* how many steps, and do you need to see the flow? More than about three steps, or a flow you'll need to explain to someone → orchestration.

*The trap:* sagas are **not isolated**. Intermediate states are visible to everyone else — another reader can see the order created but not yet paid. You must decide what that reader sees, and some steps genuinely can't be compensated (an email is sent, a physical item shipped). Order your steps so the irreversible one is last, and treat the step after which you can no longer go back as a real design landmark.

**Outbox.** Write the event to a table **in the same transaction** as the data change, then have a separate relay publish committed rows. The database commit becomes the single source of truth.

*Use when* a state change must reliably produce a message. This is the fix for **dual writes** — save to the DB, then publish — which diverges permanently the first time the second call fails, with nothing to reconcile it.

*Cost:* a relay to run and monitor, and publication is now asynchronous. Consumers must tolerate duplicates, because the relay can publish and crash before recording that it did.

**Inbox.** The mirror image for inbound messages: record the message id in a table, in the same transaction as the effect, and use a uniqueness constraint to drop repeats.

*Use when* consuming at-least-once delivery, which is all real queues and every webhook. *The subtle bug worth knowing:* if you insert the dedup row and *then* enqueue the work as two separate steps, a crash between them loses the event permanently — and the retry gets deduplicated away by the very row that was supposed to protect it. Record and enqueue must commit together.

**Idempotency key.** The caller supplies a unique key; you store it under a uniqueness constraint alongside the effect and the response, so a replay returns the original outcome instead of repeating the work.

*Use when* a write is retryable and repeating it would be harmful — payments, orders, transfers. Since a timeout is an unknown outcome, **any** retryable write across a boundary needs one.

*Getting it right:* scope the key to the caller so two clients can't collide; store a hash of the request and reject a reused key carrying a different body; store the original **response**, because "do nothing on conflict" forgets what the first call answered. Handle the *concurrent* replay too — a retry that arrives while the first call is still running must not fall through to the effect.

**Prefer natural idempotency where you can get it.** An upsert keyed on business identity, or `SET status = 'shipped'` rather than an increment, needs no key at all. Absolute values are replay-safe; relative ones double-apply.

## Surviving partial failure

**Timeout on every call.** Not a pattern so much as the precondition for all of them. An unbounded wait is a hang waiting for a bad day, and it converts one slow dependency into an outage.

**Retry with exponential backoff and jitter.** Retry only *transient* failures (429, 503, connection errors, timeouts) and only *idempotent* operations. Backoff prevents hammering something already struggling; **jitter** prevents every client retrying in lockstep and creating a synchronised thundering herd.

*Never* retry a `400`, `403` or `422` — the answer won't change. Obey `Retry-After` when the server sends it, and let it override your own backoff; ignoring it is how a throttle becomes a ban. Cap total attempts and have a plan for exhaustion.

**Circuit breaker.** After repeated failures, stop calling a dependency for a cooldown. Three states: *closed* (normal), *open* (fail immediately without calling), *half-open* (let a trial request through to test recovery).

*Use when* a dependency's failure would otherwise park all your workers waiting on it. The value is twofold: you fail fast instead of slowly, and you give the struggling dependency room to recover instead of retrying it to death.

*Cost:* while open, you reject requests that might have succeeded. Scope the breaker correctly — per dependency, sometimes per endpoint or per shard. One global breaker for a service with several independent backends will trip on the wrong signal.

**Bulkhead.** Isolate resources per dependency so one exhausted pool can't starve everything else.

**Hedged request.** Send the same read to a second replica after a short delay and take whichever answers first.

*Use when* tail latency matters and the operation is a safe, idempotent read. *Cost:* extra load — typically send the hedge only after the p95 elapses so you pay for a small fraction of requests, and never hedge a write.

**Graceful degradation.** A failed *optional* dependency should produce a partial or cached result, not a `500` for the whole request. Recommendations, avatars and related-items should never take down a product page.

**Dead-letter queue.** After N failed attempts, move the message aside rather than retrying forever or blocking the partition behind it.

*Use when* consuming any queue. Then actually monitor the DLQ — an unwatched one is a silent data-loss channel. And note that dead-lettering a message breaks ordering for its key, which matters if you relied on that.

## Reading and writing at scale

**CQRS.** Separate the write model from the read model. Writes go through the domain model and its invariants; reads come from a shape purpose-built for querying.

*Use when* reads and writes genuinely diverge — very different shapes, very different volumes, or reads needing joins across aggregates that the write model deliberately keeps apart.

*Cost, and it's a real one:* the read model is eventually consistent, so a user can submit a change and not see it. That must be designed for — an optimistic local update, or an explicit "processing" state. Don't adopt CQRS just because it sounds tidy; two models are twice the code, and most systems don't need it.

**Read model / projection.** A derived, rebuildable view fed from the source of truth.

*The rule that keeps this safe:* a projection must **never** be the system of record, and you must be able to say **what rebuilds it and how long that takes**. If you can't rebuild it, it isn't a projection — it's primary data with no backup.

**Event sourcing.** Store the sequence of events as the source of truth and derive current state by replaying them.

*Use when* history *is* the requirement — audit, regulatory reconstruction, temporal queries, or debugging by replay.

*Cost:* high, and frequently underestimated. Schema evolution of old events is forever (you can never delete or reinterpret one), snapshots become necessary for performance, and "delete a user's data" collides awkwardly with an immutable log. **An append-only audit table alongside a normal mutable model gets most of the benefit for a fraction of the cost** — reach for that first and only go further if it genuinely doesn't answer the question.

**Sharding / partitioning.** Split data across nodes by a key.

*The whole decision is the key.* Two opposite failure modes: too coarse and everything lands in one partition (a monotonic timestamp puts every write on the newest shard); too fine and every read fans out across all of them. Pick a key where load spreads *and* the common read carries the key. In a key-value or wide-column store this is the least reversible decision you'll make — changing it means rewriting the dataset.

**Cache-aside, read-through, write-through.** Where the cache sits relative to the load. Whichever you choose, the obligation is the same: **name the invalidation story.** "I'll cache it" without an answer to "when is it wrong?" is a bug with a delay. Version the cache key so a deploy that changes the shape can't read stale entries, and make sure a cold cache is a slow request rather than a wrong one.

## Coordination

**Leader election with a lease.** Exactly one instance does a thing — runs the scheduler, drives the relay — by holding a lease that **expires**, so a crashed leader is automatically replaced.

*Use when* work must happen once across N replicas. A cron on four replicas runs the nightly billing job four times.

**Fencing token.** The lease carries a monotonically increasing number, and every protected write includes it; the resource rejects writes bearing an old token.

*Use when* correctness depends on single-writer, which is whenever you used a lease for anything other than a hint. This closes the failure that leases alone can't: a leader pauses (GC, network partition), its lease expires, a new leader takes over, then the old one wakes up believing it's still leader and writes. Without fencing, that write lands. **A distributed lock without fencing is a performance optimisation, not a correctness mechanism** — don't use one to protect a money invariant the database could enforce directly with an atomic conditional update.

**Sidecar / ambassador.** Put cross-cutting concerns — TLS, retries, telemetry, service discovery — in a process alongside the app rather than in the app.

*Use when* many services in different languages need the same behaviour consistently. *Cost:* another process per instance to deploy, monitor and debug; failures now happen in a place your application logs don't cover.

## Evolving a system

**Strangler fig.** Put a routing layer in front of a legacy system and move functionality behind it piece by piece, until nothing routes to the old system and it can be switched off.

*Use when* replacing something you can't take offline. It's the honest alternative to a rewrite, which is the pattern that reliably fails: a rewrite must reach feature parity with a moving target before it delivers anything.

*Cost:* both systems run at once, sometimes sharing data, for as long as it takes. Budget for the interim state, and set a real deadline — the classic failure is a migration that stalls at 70% and leaves you maintaining two systems forever.

**Anti-corruption layer.** A translation boundary between your model and an external one, so their concepts don't leak into your domain.

*Use when* integrating a legacy system or third-party API whose model is different from yours. Without one, their field names and their weird nullable enum spread through your codebase and you inherit their design decisions permanently. This is Adapter applied at the scale of a whole model.

**Backend-for-frontend.** One tailored backend per client type, rather than a single API compromising between all of them.

*Use when* clients have genuinely divergent needs — a mobile app wanting few round trips and small payloads, a web app wanting rich detail. *Cost:* more services and duplicated logic, so consider whether one flexible query layer would serve instead.

**Expand-migrate-contract.** Change a schema or contract in three deploys: add the new thing alongside the old, migrate readers and writers over, then remove the old one once nothing references it.

*Use when* changing anything under live traffic, which is any change to a running system. The single-deploy rename — drop the old column and ship new code together — breaks every instance still running the previous version. This is the pattern that most reliably prevents self-inflicted outages, and the reason names are worth spending time on before there's data behind them.
