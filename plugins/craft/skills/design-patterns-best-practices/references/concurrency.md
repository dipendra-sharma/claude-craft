# Concurrency and reactive patterns

Patterns for when work happens at the same time as other work. The organising question is always the same: **what state is shared, and who is allowed to touch it?** Most concurrency bugs are an answer nobody wrote down.

This file decides *which* pattern. For the correctness rules around shared mutable state generally, `coding-best-practices` covers atomicity, lock ordering and cancellation; for server-side concurrency across requests, `backend-best-practices`; for races inside a screen, `ui-state-best-practices`.

## Contents

- [Choosing by symptom](#choosing-by-symptom)
- [Avoid sharing altogether](#avoid-sharing-altogether)
- [Share by communicating](#share-by-communicating)
- [Share with coordination](#share-with-coordination)
- [Controlling flow and load](#controlling-flow-and-load)
- [Structuring concurrent work](#structuring-concurrent-work)
- [Reactive stream patterns](#reactive-stream-patterns)

## Choosing by symptom

| Symptom | Reach for |
|---|---|
| Two callers read-then-write and one update is lost | atomic conditional update (CAS); or confine the state to one owner |
| Shared object mutated from several threads, occasional corruption | immutability; copy-on-write; actor; confinement |
| Deadlock, or intermittent hangs under load | lock ordering; timeouts on acquisition; remove the second lock by confining state |
| Producer outruns consumer; memory grows until OOM | bounded queue + backpressure |
| One slow dependency parks every worker | bulkhead (separate pools) + semaphore + timeouts |
| Fast-typing user sees stale results overwrite fresh ones | latest-wins cancellation |
| Same expensive request fired N times concurrently | single-flight / request coalescing |
| Need many independent calls, then all results | fork-join / scatter-gather |
| Background work outlives the screen or request that started it | structured concurrency with a scope |
| Event handler does CPU work and the whole app stalls | move off the event loop to a worker pool |

## Avoid sharing altogether

The cheapest concurrency pattern is not having the problem.

**Immutability.** If a value can't change, it can be read from any number of threads with no coordination at all. This eliminates the entire category rather than managing it.

*Use when* you can — which is more often than people assume. *Cost:* allocation, mitigated by persistent structures with structural sharing.

**Copy-on-write.** Readers see a consistent immutable snapshot; a writer builds a new version and swaps a single reference atomically.

*Use when* reads vastly outnumber writes and readers tolerate slightly stale data — configuration, routing tables, feature flags, subscriber lists. *Don't* when writes are frequent; you'll copy constantly.

**Confinement / single ownership.** Give mutable state exactly one owner and let everyone else send it messages. No lock is needed because there's no concurrent access.

*Use when* state has a natural owner. This is the idea underneath actors, event loops and single-writer designs, and it's usually the right first move.

**Thread-local / task-local.** Give each worker its own copy. Sharing disappears by construction.

*Use when* the state is genuinely per-worker — a scratch buffer, a request context, a non-thread-safe formatter. *Cost:* on pooled threads, leftover state leaks into the next task; clear it. In `async` runtimes tasks migrate between threads, so thread-local is often the *wrong* mechanism there — use the task-scoped equivalent.

## Share by communicating

**Actor.** State lives inside one actor, which processes messages from a mailbox strictly one at a time. Because only the actor touches its state, no locks are needed, and the mailbox serialises everything.

*Use when* an entity has identity plus mutable state and receives concurrent requests — a game session, a device connection, an order in flight, a rate limiter per user. Scales well because actors are independent.

*Cost:* everything becomes asynchronous, so request/response needs correlation. **Mailboxes must be bounded** or a slow actor becomes a memory leak. A single actor is a serialisation point — if every message goes through one, you built a bottleneck. Debugging is harder: the stack trace shows the mailbox, not the sender.

**CSP / channels.** Independent tasks communicate by passing values over channels. Emphasis is on the *conduit* rather than the recipient's identity — you don't address an actor, you write to a channel someone is reading.

*Use when* modelling pipelines and hand-offs between stages, or fan-in from many producers to one consumer. *Cost:* an unbuffered channel couples producer and consumer timing (both block until the hand-off), which is sometimes exactly the synchronisation you want and sometimes a deadlock.

**Actor vs CSP — decide by asking:** *do I address a recipient, or a pipe?* An entity with identity and its own state → actor. A stage in a data pipeline → channel.

**Producer-consumer.** Producers put work on a queue; a pool of consumers takes it off. Decouples arrival rate from processing rate and absorbs bursts.

*Use when* work arrives unevenly. **Bound the queue** — see below. Decide explicitly what happens when it's full, and what happens to a work item whose consumer crashes mid-processing.

## Share with coordination

When state must be shared and mutable, the pattern is about making the dangerous window disappear.

**Atomic conditional update (compare-and-swap).** Collapse read-check-write into one indivisible operation, so there's no window between the check and the act. `UPDATE ... WHERE version = expected`, `compareAndSet(old, new)`, `computeIfAbsent`.

*Use when* the invariant can be expressed in one operation. This is the first thing to reach for, ahead of any lock. *Cost:* under high contention, retries burn CPU.

**Verify atomicity, don't infer it from the name.** A method called `getOrCompute` is only as atomic as its implementation. Some concurrent-map implementations guarantee single computation; plain hash maps and hand-rolled helpers do not. Reading the documentation is the difference between closing a race and believing you closed it.

**Optimistic vs pessimistic locking.**
- **Optimistic** — carry a version, write conditionally, retry on conflict. Best when conflicts are *rare*: no lock is held, so nothing blocks.
- **Pessimistic** — take a lock, then act. Best when conflicts are *common*, because retry storms cost more than waiting.

*Decide by asking:* how often do two writers actually collide? Guessing wrong is a throughput problem, not a correctness one.

**Lock ordering.** When multiple locks are unavoidable, define a total order (by id, by address, by name) and acquire in that order everywhere. Two paths taking the same two locks in opposite orders is the textbook deadlock, and it will pass every single-threaded test.

*Always* pair with a timeout on acquisition, so a cycle fails loudly instead of hanging forever.

**Read-write lock.** Many concurrent readers, exclusive writers.

*Use when* reads dominate and the data is too large or too write-heavy for copy-on-write. *Cost:* more complex than a plain lock, and writers can starve under continuous read load. Try copy-on-write first — it's usually simpler and faster.

**Single-flight / request coalescing.** When N callers ask for the same uncached thing at once, let one do the work and have the rest wait on that result.

*Use when* a cache miss on a hot key would otherwise stampede the backend. Essential in front of any expensive shared resource.

## Controlling flow and load

**Backpressure.** When a consumer can't keep up, the *producer must slow down* — not buffer indefinitely. An unbounded queue doesn't solve an overload problem, it converts a visible slowdown into an invisible memory leak and then an OOM.

Mechanisms, in rough order of preference: block the producer; return an explicit "try later" (`429`/`503`); drop the oldest or newest item deliberately; sample. All four are decisions worth writing down — the failure mode of "we'll just buffer" is the worst of them.

*Use when* producer and consumer rates are independent. Which is always, so bound every queue.

**Semaphore / permit-limited concurrency.** Cap how many operations run at once.

*Use when* a downstream resource has a hard limit — connection count, API rate limit, GPU memory, file handles.

**Bulkhead.** Give each dependency its own isolated pool, so one sick dependency can't consume every worker and take unrelated features down with it.

*Use when* one process calls several dependencies with different reliability. The pattern's value shows up precisely when something breaks: without it, a slow recommendation service can take out checkout.

**Load shedding.** Reject work *before* the system saturates, rather than accepting everything and degrading for everyone. A fast `503` beats a request that blocks for sixty seconds and then fails anyway.

**Debounce and throttle.** Two different tools people mix up.
- **Debounce** — wait until activity *stops*, then act once. For "search as the user types": you want the query after they pause.
- **Throttle** — act at most once per interval, during continuous activity. For scroll and resize handlers: you want regular updates, just fewer.

*Decide by asking:* do I want the **final** value after a burst (debounce), or **periodic** values during it (throttle)?

## Structuring concurrent work

**Structured concurrency.** Concurrent work is bound to a lexical scope: the scope doesn't exit until its children finish, cancelling the scope cancels the children, and a child's failure propagates.

*Use when* you start concurrent work at all. This is the modern default and it eliminates a whole class of bug — the orphaned task that outlives its purpose, keeps a reference alive, and writes its result into a screen that's gone. If a task's lifetime isn't tied to something, that's the bug.

**Fork-join / scatter-gather.** Launch independent operations concurrently, wait for all, combine. Latency becomes the slowest call instead of the sum.

*Use when* calls are genuinely independent. *Cost:* fan-out multiplies tail latency — with ten parallel calls you wait for the worst of ten, so the p99 of the whole is worse than the p99 of one. Give every branch a timeout and decide whether partial results are acceptable.

**Pipeline.** Stages connected by queues, each stage concurrent with the others.

*Use when* work has distinct sequential phases with different costs. Lets you scale each stage independently. *Cost:* the slowest stage sets the throughput, and every inter-stage queue needs a bound.

**Event loop / reactor.** One thread handles many connections by never blocking; work is registered as callbacks or continuations.

*Use when* the workload is IO-bound with high concurrency. *Cost, and it's the big one:* **any blocking or CPU-heavy work on the loop stalls everything.** A synchronous driver, parsing a large payload inline, or a password hash on the loop thread halts every in-flight request. Move that work to a worker pool, and never mix blocking libraries into an async stack.

**Latest-wins cancellation.** When a new request supersedes an older one, cancel the old work rather than letting a stale response land after a fresh one.

*Use when* rapid user input triggers async work — search-as-you-type is the canonical case. Prefer **true cancellation** that aborts the in-flight work over a guard flag that merely discards a late result: the guard still pays for the wasted request. Note that cancelling usually surfaces as a cancellation error you must swallow deliberately, or you'll flood your error reporting on every keystroke.

## Reactive stream patterns

Streams are Observer plus operators plus, in good implementations, backpressure. The patterns worth naming:

- **Map / filter / scan** — transform, drop, accumulate. `scan` is the stream form of fold and the natural home for reducer-style state.
- **switchMap / flatMapLatest** — a new input cancels the in-flight inner stream. This *is* latest-wins, expressed as an operator, and it's the correct choice for search pipelines.
- **concatMap** — process inner streams strictly in order, one after another. Use when ordering matters and you must not drop work.
- **flatMap / mergeMap** — run inner streams concurrently, order not guaranteed. Fastest, and wrong whenever order matters.
- **Decide by asking:** *should a new input cancel the old work (switch), queue behind it (concat), or run alongside it (merge)?* Choosing `merge` when you meant `switch` is one of the most common real bugs in reactive code.
- **debounce / throttle / sample** — rate control, as above.
- **combineLatest / zip** — `combineLatest` emits on any input change using the newest of each; `zip` pairs them strictly by index and waits. `combineLatest` on two rapidly-changing sources emits intermediate combinations that were never simultaneously true, which is a real source of flicker.
- **share / publish** — multicast one subscription to many subscribers, so a cold stream's side effect happens once rather than per subscriber. Forgetting this means N HTTP requests for N subscribers.
- **retry / retryWhen** — resubscribe on failure, with backoff. Only for transient failures, and only on idempotent work.
