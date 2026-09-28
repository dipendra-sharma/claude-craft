---
name: backend-best-practices
description: "Server-side quality baseline — load for any backend work in any stack: REST/gRPC/GraphQL endpoints, transactions, migrations, caching, queues and consumers, background jobs, webhooks, auth, service-to-service calls, service lifecycle. Owns the runtime and safety layer around the datastore: injection safety, transaction and isolation semantics, locks and deadlocks, idempotency, retries and timeouts, pooling, authorization, failure under load. Loads together with coding-best-practices, which owns general code quality. Skip for pure frontend/UI (see ui-state-best-practices), and for anything about how a query is written, indexed or costed — that is database-best-practices."
---

# Backend Best Practices

A polyglot server-side reviewer and teacher. Every principle here is language- and framework-independent; examples are pseudocode. **Always render Bad/Good pairs in the user's actual stack** (their DB, their web framework, their ORM/driver, their queue) — a Postgres project gets Postgres, a Go service gets Go idioms, a Node/Express app gets Express. You both **review** backend code and **teach** these principles on demand — every point carries a concrete Bad/Good pair plus one line of *why*.

**This skill owns backend-specific concerns only.** General code quality (naming, SRP, DRY, guard clauses, error-handling *style*, dead code, comments, scope discipline) belongs to `coding-best-practices` — **the two always run as a pair on server-side code: load that skill too if it isn't already active**, then don't re-teach its material here. UI state and rendering belong to `ui-state-best-practices`. **The data model *and the query* belong to `database-best-practices`** — which datasets exist, their grain and identity, normalization and deliberate duplication, which indexes and partition keys should exist, how a read is written and shaped, and what it costs in bytes. Load it whenever the question is about the data or the SQL itself; this skill does not restate any of it. What stays here is the runtime and safety layer wrapped around that query: parameterization and injection, transactions and isolation, locks and deadlocks, retries and idempotency, pooling and timeouts, and executing migrations without locking production. When a backend issue is really a general-quality or data-model issue, name it and defer. This skill goes *deep* where the server is the risk surface: the database, the network boundary, concurrency across requests, and failure under load.

## Skill chaining

These compose — invoke the ones that apply with the Skill tool rather than re-teaching their material here.

| Invoke | When | It owns |
|---|---|---|
| `database-best-practices` | **any question about the data or the query** — which datasets exist, grain, keys, constraints, which indexes or partition keys, how a query is written or shaped, why it's slow, what a read costs | the data model, the query, and its access paths. **On database work it leads and this skill supports it** |
| `coding-best-practices` | always, on any code work | naming, structure, error handling, resource lifecycle |
| `testing-best-practices` | writing or fixing tests | test level and shape, doubles, determinism |
| `ui-state-best-practices` | the work reaches UI state | state shape and data flow |

Chain in both directions: if `database-best-practices` invoked you for the runtime layer, hand the modeling question back rather than answering it here.

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap, not one each — pick the highest-impact issues across the whole set, and never restate a point a sibling already made.

## The objective: correct, safe, and survives production load

A backend request rarely fails alone in a unit test — it fails on the 10,000th concurrent call, on the retry after a timeout, on the row that another transaction just changed, on the deploy where the old and new schema run side by side. Aim for code that is **correct under concurrency, safe against hostile input, and predictable under load and partial failure.** When principles conflict, resolve in this order:

1. **Correct & consistent** — never returns or persists wrong data, even under races, retries, or partial failure. Data integrity is the one thing a backend cannot trade away.
2. **Safe** — hostile input can't inject, escalate, exhaust, or leak; every trust boundary is guarded.
3. **Resilient & performant** — degrades gracefully, bounds every resource, and meets latency/throughput budgets without wasting round-trips.

When **reviewing**, push code toward this and skip nitpicks; flag the most impactful issues first (data-corruption and security risks before style). When **writing**, produce this version directly.

## How to operate

**Establish the stack first — always.** Before reviewing or writing, pin down and let it shape every suggestion:

- **Database & data model** — which engine (Postgres/MySQL/SQLite/Mongo/DynamoDB/Cassandra/ClickHouse/…), **plus every auxiliary store** (Redis, search index, warehouse, queue) and what each is actually the source of truth for; the transaction & isolation semantics; and how access happens (raw driver, query builder, ORM). Advice that's right for Postgres MVCC can be wrong for MySQL or a document store — once you know the engine, apply its list in §21.
- **API surface** — REST, gRPC, GraphQL, or an internal RPC; synchronous request/response vs event-driven. HTTP-status advice doesn't map onto a gRPC service unchanged.
- **Runtime & concurrency model** — threads, async event loop, goroutines, per-request isolation vs a shared worker pool. This decides whether §12 (concurrency) even applies and how.
- **Deployment shape** — single instance vs horizontally scaled, behind a load balancer, containerized/serverless. Statelessness (§13) matters far more when N replicas share traffic.
- **Target versions** — read the manifest (see `coding-best-practices` *Currency*); never recommend a driver/framework API the project can't run, and web-search when unsure which version introduced it.

**When reviewing:** read the code → flag the highest-impact backend risks first (data loss/corruption, injection/authz holes, unbounded resource use) → for each, a Bad snippet and a Good snippet in the user's stack plus one line of *why* → limit to 5–7 issues unless asked for exhaustive feedback.

**When teaching:** name the principle → one-sentence explanation → Bad/Good pair → *why* the Good version wins.

**Output format** for each issue or principle:

```
### [Principle]
[one-sentence explanation]
**Bad:**  [code that violates it]
**Good:** [code that follows it]
[why the Good version wins — 1-2 sentences]
```

**Voice** — the output format is for reviewing and teaching; when writing code, apply the rules silently. Section numbers are internal scaffolding: never cite them in replies. Both rules live in `coding-best-practices` and apply here unchanged.

---

## Data & persistence

### 1. Query safety — parameterize, and never interpolate an identifier
A query is an injection surface, and that part is this skill's. **Everything about how a query is *written*, *shaped*, or *costed* belongs to `database-best-practices`** — load it for that and don't re-derive it here.

**Bad:** `db.query("SELECT * FROM users WHERE name = '" + name + "'")` — string concatenation, so the value can close the quote and change the statement.
**Good:** `db.query("SELECT id, name FROM users WHERE name = $1", [name])` — a bound parameter, which the driver can never reinterpret as SQL.
- **Bind every value** — prepared statements or ORM bindings, no exceptions, no "it's just an internal id."
- **Identifiers can't be bound.** A parameter stands in for a *value*, never for a column or table name — a client-supplied `sort=` or `filter=` field goes through an allowlist before it reaches `ORDER BY`/`WHERE`. Interpolating it is the injection that survives "we use prepared statements."
- **Everything else about queries → `database-best-practices`:** N+1 and round-trip count, `SELECT *` and column projection, sargability, reading `EXPLAIN`, which indexes should exist, keyset vs `OFFSET`, `COUNT(*)` cost, and what a read costs in bytes. That skill owns the access path; this one owns the transaction, lock, pool and timeout wrapped around it (§2, §4, §12).

### 2. Transactions & consistency boundaries
A write that spans multiple statements must be all-or-nothing, or a crash between them leaves corrupt state. Wrap related writes in one transaction, keep it short, and choose the isolation level deliberately.

**Bad:** `debit(from, amt); credit(to, amt)` as two separate commits — a failure between them loses money.
**Good:** `tx { debit(from, amt); credit(to, amt) }` — one atomic unit; a failure rolls both back.
- **Keep transactions short** — never hold one open across a network call, an external API, or user think-time; you'll exhaust the pool and grow lock contention.
- **Prefer the atomic conditional write to an isolation level — isolation is not portable.** Read-modify-write on a balance or inventory count wants `UPDATE … SET x = x - 1 WHERE id = $1 AND x >= 1`, which is correct on every engine. Raising isolation is engine-specific and easy to get wrong: **Postgres** `REPEATABLE READ`/`SERIALIZABLE` abort conflicting transactions with `40001` and the application *must* retry the whole transaction; **InnoDB** `REPEATABLE READ` does **not** abort — a concurrent `UPDATE`/`DELETE` can affect rows committed after your snapshot, so the lost update fails *silently* (you only see `40001` from deadlock, 1213), and `SERIALIZABLE` there turns every plain `SELECT` into a locking read; **SQL Server** `SERIALIZABLE` is range locks and blocking, producing waits and deadlocks (1205), never a serialization failure — use `SNAPSHOT` if you want optimistic behaviour.
- **Note the recency inversion.** Raising isolation gives you a *stale, stable* snapshot taken at transaction start — stronger isolation, weaker recency. If you need to see the latest committed write, that is `READ COMMITTED` per statement, not `SERIALIZABLE`.
- **Don't wrap read-only work in a transaction** it doesn't need, and don't stretch a boundary around unrelated writes just because they're nearby.

### 3. Migrating a schema without downtime
Migrations run while the *old* code is still serving traffic, so every change must be safe against both versions at once. (*What* the schema should contain — tables, keys, normalization, constraints, indexes — is `database-best-practices`; this section is about changing it safely on a live system.)

**Bad:** a single migration that renames `email` → `email_address` and deploys new code together — the old instances still writing `email` break the instant the column vanishes.
**Good:** **expand → migrate → contract**: add `email_address`, backfill + dual-write, cut reads over, then drop `email` in a *later* deploy once no code references it.
- **Every migration is backward-compatible with the currently-running code.** No destructive change (drop/rename/narrow-type) in the same deploy that needs it — split across releases.
- **Backfill in batches**, not one giant `UPDATE` that locks the table; add indexes concurrently where the engine supports it.
- **Run migrations as their own deploy step**, not on every replica's boot — N instances racing to apply the same migration is a lock storm at best and a half-applied schema at worst. One runner finishes before the new code takes traffic.

### 4. Connection & resource management
Connections, cursors, and file handles are finite and expensive; leaking them under load is a slow-motion outage. Reuse via a pool, bound every wait, and stream what won't fit in memory.

**Bad:** `conn = db.connect(); rows = conn.query("SELECT * FROM events")` — a fresh connection per call and the whole table materialized in memory.
**Good:** acquire from a shared pool, set a statement timeout, and stream/paginate the result set; release on every exit path (see `coding-best-practices` §14, resource lifecycle).
- **Size the pool small, and size the fleet, not the instance.** Start from `(cores × 2) + effective_spindles` per instance, then check the real constraint: `pool_size × replicas + migrations + admin headroom` must fit under the server's `max_connections`. Bigger pools are slower, not faster — past the database's real parallelism you are queueing *inside* the database, where you can't see it, instead of in your own pool, where you can. Serverless or per-invocation runtimes get a proxy/pooler, never a pool per invocation.
- **Timeout every external wait** — DB query, HTTP call, cache lookup. A call with no timeout is a hang waiting to happen; one slow dependency shouldn't exhaust all your workers.

---

## API & contracts

### 5. API design & versioning
An API is a contract other people build on; breaking it silently breaks them. Model resources and verbs the way the protocol intends, and never change a published contract's meaning in place.

**Bad:** `POST /getUserData?delete=true` — verb in the path, action in a query flag, unclear semantics.
**Good (REST):** `GET /users/{id}` to read, `DELETE /users/{id}` to remove — the HTTP method carries the intent; the status code carries the outcome (200/201/204/400/404/409/422).
- **Use correct status codes** — 4xx for client faults, 5xx for server faults; don't return `200 {error: ...}` (monitoring and clients can't tell success from failure). Adapt to the protocol: gRPC status codes, GraphQL error extensions.
- **Know which methods are safe and which are idempotent — from the spec, not from intuition.** Safe: `GET`, `HEAD`, `OPTIONS`, `TRACE`. Idempotent: those plus `PUT` and `DELETE`. **Neither: `POST` and `PATCH`.** `PUT` is a *full replacement* — a partial `PUT` is a lost-update bug. `PATCH` carries no idempotency guarantee, so it uses absolute values under a declared patch media type (`application/merge-patch+json`, `application/json-patch+json`) — never relative ones like `{"balance": "+10"}`, which double-apply on retry — or is gated by `If-Match`/an idempotency key (§10). Full table and the conditional-request rules in `references/http-semantics.md`.
- **Version before you break.** Additive changes (new optional field) are safe; removing/renaming a field or changing a type is breaking — introduce a new version or field and deprecate the old one.
- **The contract is every observable behaviour, not the documented subset** (Hyrum's Law). With enough callers, someone depends on the incidental field order, the error string they regex, the fact that a list happens to come back sorted, even the latency. Two consequences that change how you work: expose *deliberately*, because anything observable is a commitment you didn't mean to make; and don't read a green contract-test suite as "safe to ship" — it only checks what you thought to promise, which is precisely not where this bites.
- **Don't run two live versions longer than the migration takes.** Every extra version multiplies what you patch, test and secure, and callers who share a client library get forced onto different versions of it. Version to buy migration time, publish a sunset date, and return `410 Gone` after it (`references/http-semantics.md` §1). Extend rather than fork wherever an additive optional field would do the job.
- **Make responses predictable** — stable field names, documented nullability, consistent casing; clients hard-code these.
- **HTTP has more surface than status + body** — caching and conditional headers, cookie and security headers, CORS, rate-limit and trace headers, payload sizing, deprecation signaling. `references/http-semantics.md` is the checklist for the REST layer beneath the conventions in §9.
- **Non-REST protocols have their own traps** — gRPC deadlines, status codes and proto evolution; GraphQL batching, depth/complexity limits and per-field authorization. Read `references/protocols.md` when the API isn't plain REST.

### 6. Pagination, filtering & bounded responses
Any endpoint that returns a collection will eventually meet a caller with a million rows. Never return an unbounded list — bound it at the API and the query.

**Bad:** `GET /orders` returning every row — grows without limit, eventually OOMs the service or times out.
**Good:** `GET /orders?limit=50&cursor=…` — a bounded page per call, with an opaque cursor the client round-trips.
- **Cap the page size** server-side (clamp `limit` to a documented max); a client asking for 1,000,000 shouldn't get it. This is the API's job and it stays here.
- **Expose a cursor, not an offset**, so the contract doesn't promise stable numbering it can't keep under concurrent inserts. **How the cursor is implemented as a query** — keyset predicates, the tie-breaker column, why `OFFSET` degrades — is `database-best-practices`.

### 7. Error contracts — consistent shape, no leaked internals
Callers program against your error responses, and attackers read them. Return a consistent, minimal error shape with the right status — never a raw exception.

**Bad:** unhandled exception → `500` with the stack trace, SQL, and file paths in the body — leaks internals *and* gives clients nothing machine-readable.
**Good:** a stable envelope (`{ "error": { "code": "ORDER_NOT_FOUND", "message": "…" } }`) with the correct status; log the full detail server-side, return only what the client needs.
- **Never leak internals** to clients — no stack traces, SQL, secrets, or internal hostnames in responses (ties to backend security, §18, and `coding-best-practices` §8).
- **Distinguish client from server errors** in both status and code so clients can decide whether retrying will help.

### 8. Input validation at the boundary
Everything crossing into the service — request bodies, query params, headers, webhook payloads, uploaded files, message bodies — is untrusted until validated. Validate and normalize *once, at the edge*, so inner code and the DB can trust it.

**Bad:** pass `req.body` straight into an ORM `create()` — **mass assignment**: a caller sets `isAdmin: true` or `balance: 999999` on fields you never meant to expose.
**Good:** validate against an explicit schema/DTO and allowlist the writable fields; reject unknown or out-of-range values with `400/422` before they reach the model.
- **Allowlist, don't blocklist** — enumerate what's permitted (fields, enum values, ranges), not what's forbidden.
- **Validate at the boundary, trust internally** — don't re-validate the same value on every internal hop (that's noise; see `coding-best-practices` §8). The edge is the one place it must happen.
- **Files go to object storage, not through the API.** Hand out a presigned or scoped upload URL with a size cap and allowed content types, store the object key plus validated metadata, and let payloads carry file *ids* — never bytes through a request body or a blob column.
- **What comes *back* from a call you made crosses the boundary too.** The list above is all inbound requests; the reply from a payment provider, a partner API, or a sibling internal service is just as much data you didn't write. Parse it against a schema before it reaches your logic. A degraded dependency returns nulls where you expect objects and truncated pages that look like empty ones; a compromised one returns text that becomes instructions the moment it lands in a prompt, a template, or a log line someone later trusts.

### 9. Consistent request/response conventions (new projects)
The most useful property of an API is predictability: a client that learns one endpoint should be able to guess the rest. On a new project you get that almost for free by deciding a handful of request/response conventions **once**, writing them down, and applying them everywhere. The specific choices below matter far less than choosing one and never drifting — *consistency beats any particular format*, so treat the defaults as sensible starting points, not laws, and match an existing project's conventions over these.

**Bad:** `GET /users` returns `[…]`, `GET /orders` returns `{ "data": […] }`, one error is `{ "error": "…" }` and another is `{ "message": "…", "code": 42 }` — every endpoint is a new surprise the client must special-case.
**Good:** one documented convention set — every collection wrapped with the same pagination metadata, every error the same shape, timestamps always ISO-8601 UTC — so client code written for one endpoint works for all of them.

Decide these once and never drift: resource naming and URL shape (§5); the response envelope (single resources unwrapped, collections always wrapped in an object with pagination metadata, no generic `data` key); the pagination shape (cursor by default, §6); one error shape (§7); field conventions (one casing, ISO-8601 UTC timestamps, money as integer minor units or a decimal type, enums as strings, a null-vs-omit policy); a fixed outcome→status-code table (§5, §7); and how idempotency keys (§10), correlation ids (§19), filtering/sorting and content negotiation are expressed.

`references/api-conventions.md` is one fully worked set with the reasoning and the main alternative for each choice — copy it for a greenfield project or use it to model your own. It is an illustration, not a mandate.

---

## Reliability & scale

### 10. Idempotency — retries must be safe
Networks time out, clients retry, queues deliver at-least-once. If replaying the same request duplicates an effect (double charge, double order), the system is broken by design. Make write operations idempotent.

**Bad:** `POST /charge` inserts a payment row every call — a client retry after a timeout charges twice.
**Good:** require an idempotency key; in **one transaction** insert the key under a unique constraint, perform the effect, and store the response — so a replay returns the original outcome without repeating the effect.
- **Prefer natural idempotency** — upserts keyed on a business identity, `SET status = 'shipped'` (not `increment`), create-if-not-exists.
- **An idempotency key is scoped, bound, and atomic.** Scope it to the caller (user or API key) so two clients can't collide. Store a hash of the request with it and reject a reused key with a different body (`422`). Store the original response so a replay returns *that* — `ON CONFLICT DO NOTHING` alone forgets what the first call answered. **The key row, the effect, and the stored response commit together or not at all**: inserting the key, then calling the gateway, then writing the response is three commits, and a crash in the middle leaves a key with no result, so the retry either returns nothing or charges again.
- **Handle the concurrent replay, not just the sequential one.** A client retry after a timeout arrives while the first request is still running. A key whose row is still `processing` gets `409` with `Retry-After` — never fall through to the effect. If the effect is external and can't join the transaction, commit `processing` first, drive the call from that row (§14 outbox), and let a sweeper finish or fail it (§24).
- **The key names the intent, not the attempt.** It has to stay identical across every retry of one intent and differ across genuinely different ones, so it is minted once — by the client, or by the event that started the work — and carried unchanged through every retry. A `uuid()` generated *inside* the retry loop makes each retry a brand-new charge, and a timestamp suffix is the same bug in a costume. Deriving it from the payload instead (`userId:amount`) fails the other way: two legitimate identical charges collapse into one. Never let the layer doing the retrying be the layer that invents the key.
- **Set retention from the longest path that can re-deliver the request, not from storage cost.** A key that expires before a dead-letter queue is drained, a partner re-posts an unacknowledged webhook, or a chargeback window closes is protection that isn't there when it's needed — a 24-hour key behind a 7-day dead-letter replay is a duplicate on a timer. Size the window against your worst case, not your average one: duplicates are *correlated*, spiking exactly when a dependency is degraded and everything retries at once.
- This is the write-side twin of §11's retries: you can only retry safely what is idempotent.

### 11. Resilience — timeout, retry with backoff, degrade
A dependency *will* be slow or down; the question is whether it takes your service with it. Bound every call, retry transient failures politely, and fail in a way that contains the blast radius.

**Bad:** `while true: try call() except: continue` — a tight retry loop hammers a struggling dependency and spins the CPU.
**Good:** a bounded retry with **exponential backoff + jitter** on *transient* errors only, wrapped in a timeout; give up after N attempts and surface/queue the failure.
- **Retry only what's safe to retry** (idempotent ops, §10) and only *transient* failures — `429`, `503`, `502`, connection errors, and timeouts. Never a `400`/`422`/`403`.
- **Obey `Retry-After` when the server sends it** (`429`, `503`) and let it override your own backoff — ignoring it is how a throttle becomes a ban.
- **A timeout is not a failure, it is an unknown outcome.** The write may have landed. It is retryable only behind an idempotency key (§10), never as a bare `POST`.
- **Circuit-break** a repeatedly-failing dependency: stop calling it for a cooldown so it can recover and your threads aren't all parked waiting on it.
- **Degrade gracefully** — a failed *optional* dependency (recommendations, avatars) should return a partial/cached result, not a `500` for the whole request.
- **The named patterns** — circuit-breaker states and scoping, bulkheads, load shedding, retry budgets, hedged requests — plus the consistency, saga, outbox/inbox, CQRS, fencing and service-boundary vocabulary are in `references/distributed-patterns.md`. Read it when a design uses those words or should.

### 12. Concurrency & race safety (backend flavor)
Every endpoint runs concurrently with copies of itself. A read-check-write that's correct in isolation corrupts data when two requests interleave. This is `coding-best-practices` §13 applied to shared *durable* state — the DB row, the counter, the inventory count.

**Bad:** `row = SELECT stock FROM items WHERE id=$1; if row.stock > 0: UPDATE items SET stock = row.stock - 1 …` — two requests both read `1`, both write `0`, stock goes negative (lost update).
**Good (atomic):** `UPDATE items SET stock = stock - 1 WHERE id=$1 AND stock > 0` — one statement, the DB serializes it; check `rows_affected` to know if it succeeded.
- **Optimistic locking** for low contention — a `version` column, `UPDATE … WHERE version = $expected`; retry on zero rows. **Pessimistic** (`SELECT … FOR UPDATE`) when contention is high and retries are wasteful — but keep the lock's transaction short.
- **Distributed locks are not a substitute for atomicity** — a Redis lock can be lost on expiry/failover; use it for coordination, not to protect a money-critical invariant that the DB could enforce directly.
- **Acquire locks in a consistent order** across code paths to avoid deadlock (ties to `coding-best-practices` §13).

### 13. Statelessness & horizontal scaling
Behind a load balancer, consecutive requests from one user hit different instances. Externalize shared state (Redis, DB, signed token) and keep instances interchangeable; don't rely on "the same instance" handling a follow-up call.

The part that actually bites: **an in-process cache is a per-replica stale view you cannot invalidate on write.** Fine for immutable or slow-moving data where losing it is merely slow; never for anything a write must bust, because the write only busts the replica that served it and the other N keep serving the old value.

### 14. Async & messaging
Queues and event streams decouple services and absorb spikes, but they deliver *at-least-once*, can reorder, and can lose the gap between "DB committed" and "message published." Design consumers for duplicates and design producers for atomicity.

**Bad:** `save(order); publish(OrderCreated)` as two steps — a crash between them either drops the event (saved, never published) or, reordered, publishes a phantom.
**Good (outbox):** write the event to an `outbox` table *in the same transaction* as the order; a separate relay publishes committed rows — the DB commit is the single source of truth.
- **Make consumers idempotent** (§10) — the same message will arrive twice; dedup on a message/event id.
- **Handle poison messages** — a message that always fails must go to a **dead-letter queue** after N attempts, not block the partition forever or retry infinitely.
- **Don't assume ordering** unless the transport guarantees it per-key; design handlers to tolerate out-of-order arrival, or use an ordering key.
- **Know which broker model you're on — they fail differently.** Visibility-timeout brokers (SQS, RabbitMQ) redeliver a message whose lease expires. Kafka has no visibility timeout: a consumer that exceeds `max.poll.interval.ms` is *evicted from the group*, triggering a rebalance that reassigns its partitions and reprocesses from the last commit — slow processing shows up as a rebalance loop, not a redelivery. Kafka specifics (partition-count changes breaking per-key ordering, commit-after-processing, dead-lettering breaking order for a key) are in `references/distributed-patterns.md` §7.
- **Apply backpressure** — a consumer that can't keep up must slow intake (bounded prefetch), not buffer unboundedly into OOM.

### 15. Background jobs & scheduling
Work moved off the request path still needs the same discipline — plus protection against duplicate runs and stuck jobs. A cron that fires on every replica runs N times; a job with no visibility timeout gets picked up twice.

**Bad:** a `@Scheduled` cron on a service with 4 replicas → the nightly billing job runs 4 times.
**Good:** run scheduled work through a leader/lock (or a single-runner scheduler) so exactly one instance fires it; make the job itself idempotent as a backstop.
- **Set a visibility/lease timeout** on claimed jobs so a crashed worker's job is retried — but long enough that a slow job isn't stolen and run twice.
- **Bound job runtime and batch size** — a job that processes "all rows" will one day process ten million; chunk it and checkpoint progress.
- **Make long jobs resumable/idempotent** so a mid-run crash re-runs cleanly.

### 16. Blocking — never stall the request path or a shared resource
Almost every backend outage that isn't data corruption is something *blocking* something else: one slow call parks the workers, one long transaction holds a lock, one O(N) command freezes the datastore for every other client. The engine rarely dies — it just stops making progress while queues back up behind it. Treat "what does this block, and for how long?" as a required question for every call to a database, cache, queue, or peer service.

**Bad:** `tx = db.begin(); order = tx.lockRow(id); charge = paymentApi.charge(...)  // 30s timeout; tx.update(order); tx.commit()` — the row lock and a pooled connection are held across a third-party network call; under load every worker is parked and the pool is exhausted, so *unrelated* endpoints start failing too.
**Good:** do the external call *outside* the transaction, then open a short transaction to record the result (idempotently, §10) — the DB lock is held for microseconds, and a slow payment provider slows only checkout.

- **Nothing external inside a transaction or a lock** — no HTTP call, queue publish, cache round-trip, user think-time, or `sleep`. Compute first, then commit fast (§2, §12).
- **Bound every wait** — connect, read, statement, cache, lock acquisition, job lease — and give each dependency its own pool (a bulkhead) so one sick backend can't consume every worker (§4, §11).
- **No O(N) commands on a single-threaded store.** Redis runs one command at a time: `KEYS *`, `HGETALL` on a huge hash, a long Lua script, or `DEL` of a giant key blocks *every* client. `SCAN`/`UNLINK`, small keys (§21).
- **Don't block the database for everyone** — no table-locking DDL in the hot path, no million-row `UPDATE`/`DELETE` in one statement, no `FOR UPDATE` polling without `SKIP LOCKED`; set `lock_timeout`/`statement_timeout` so a blocked statement fails instead of queueing all traffic behind it (§3, §21).
- **Don't block the runtime's worker.** CPU-heavy or synchronous work on an async event loop (Node, asyncio, Netty) stalls every in-flight request — a blocking driver, parsing a 50 MB payload inline, bcrypt on the loop. Move it to a worker pool; never mix blocking drivers into an async stack.
- **Move slow work off the request path** — enqueue it and return `202` with a status handle rather than holding the client and a worker (§15).
- **Batch round-trips** — N sequential DB or cache calls hold a worker for the sum; use `MGET`, one `IN` query, a pipeline, or concurrent independent fetches (§1).
- **Keep consumers unblocked** — dead-letter poison messages after N attempts and bound prefetch (§14).
- **Fail fast and visibly** — a `429`/`503` from a bounded queue or a tripped breaker beats a request that blocks for 60s and dies anyway; load-shed *before* the pool is empty (§11, §19).

---

## Cross-cutting

### 17. Caching — invalidate, and protect against stampede
A cache trades freshness for speed; the hard parts are knowing when it's stale and surviving the moment it's empty. Cache deliberately, with a TTL and an invalidation story.

**Bad:** cache a value forever with no TTL and no invalidation — serves stale data indefinitely after the source changes.
**Good:** set a TTL appropriate to tolerable staleness, and invalidate/update on write; on a hot key, use single-flight so one miss doesn't unleash a thundering herd.
- **Name the invalidation strategy** — TTL expiry, write-through, or explicit bust on change. "I'll cache it" without answering "when is it wrong?" is a bug in waiting.
- **Prevent stampede** — when a hot key expires, thousands of requests miss at once and all hit the DB. Use single-flight (one loader, others wait) or staggered/soft TTLs.
- **Only cache what's safe to serve slightly stale**, and never cache per-user data under a shared key (a classic auth leak).
- **Version the key and treat the cache as losable** — put a schema version and every identifying input in the key (`v3:user:profile:{id}`) so a deploy that changes the shape can't read old entries, and make sure a cold or evicted cache is a slow request, never a wrong one. Engine-specific cache traps (TTL-less keys, blocking commands, eviction stealing non-cache data) are in §21.
- **HTTP caching is a header you send, not just a store you run.** Every response carries a deliberate `Cache-Control`: `no-store` (or `private`) for anything per-user or authenticated; `public, max-age` plus an `ETag` for shared data so revalidation is a `304`. A missing directive lets a CDN or browser hand one user's response to another, and `no-cache` means *revalidate*, not *don't store*. The header checklist is in `references/http-semantics.md`.

### 18. Backend security — authN/authZ, rate limits, least privilege
The server is the trust boundary; the client is not. Extends `coding-best-practices` §16 with the server-specific holes.

**Bad:** `GET /orders/{id}` returns the order if the id exists — **broken object-level authorization (IDOR)**: any logged-in user reads anyone's order by guessing ids.
**Good:** after authenticating, authorize the *specific resource* — `WHERE id=$1 AND owner_id=$currentUser` (or an explicit policy check); existence alone is never permission.
- **Authenticate then authorize on every entry point** — check *who* (authN) and *whether they may touch this resource* (authZ) on each request; never trust a client-supplied user/role/id.
- **Rate-limit and throttle** public and expensive endpoints (per user/IP/key) so one caller can't exhaust the service (DoS) or brute-force credentials.
- **Least privilege for the service itself** — the app's DB user shouldn't be superuser; its cloud role shouldn't be `*`. Scope credentials to exactly what the service needs.
- **Keep secrets out of source and logs** (env/secret manager), and **protect PII** — encrypt sensitive data at rest, don't log it, and return only fields the caller is entitled to.
- **Guard SSRF** — a URL supplied by the client and fetched server-side can reach internal metadata endpoints; allowlist destinations.
- **Credentials and sessions** — hash passwords with a slow salted algorithm (argon2id, bcrypt, scrypt; never MD5/SHA-x); short-lived access tokens, rotation on refresh, revocation on logout or privilege change; verify a JWT's algorithm and expiry server-side and never accept `alg: none`.
- **Cookie auth needs `HttpOnly`, `Secure`, `SameSite` and CSRF protection**; CORS is an allowlist of exact origins, never `*` with credentials.
- **Authorization policy lives in one place.** Scattered `if (user.role === …)` checks drift and miss a route; centralize the rule (`canAccess(user, resource)`, a policy module, row-level security) and call it from every entry point. In a multi-tenant system the tenant scope is part of every query and every index, never an afterthought (§21).
- **Audit privileged actions** — who did what to which resource and when, in an append-only record the actor can't edit.

### 19. Observability — you can't fix what you can't see
When a request fails at 3am across five services, logs, metrics, and traces are the only way in. Emit them deliberately, structured, and correlated — not as an afterthought.

**Bad:** `print("error!")` with no context — useless when it's one of a million requests and you don't know the user, request, or cause.
**Good:** structured log (`level, event, request_id, user_id, latency_ms, error`) carrying a **correlation/trace id** that threads through every service the request touches.
- **Propagate a correlation id** from the edge through downstream calls and async messages so one request is traceable end-to-end.
- **Metrics that matter** — RED (Rate, Errors, Duration) per endpoint, USE (Utilization, Saturation, Errors) for resources like the connection pool. Alert on symptoms users feel, not on CPU alone.
- **Log actionably, once, at the right level** — no logging in a tight loop, no dumping full payloads (PII + noise), no log-and-rethrow (see `coding-best-practices` §8). A log line should tell the on-call *what* and *enough to act*.

### 20. Configuration & environments
Secrets come from a secret manager, plain config from the environment — `coding-best-practices` §16 owns the "no hardcoded secrets" rule. Two things it doesn't cover:

- **Validate config at startup**, not on first use — a missing or malformed value should crash the boot loudly, not surface as a mysterious runtime error hours later (§25 wires this to readiness).
- **Gate risky changes behind feature flags** so a rollout can be turned off without a redeploy, and a migration's read/write cutover (§3) can be flipped independently of the deploy that shipped the code.

### 21. Datastore-specific anti-patterns
Every engine has failure modes that only exist there, and advice that's right for one is wrong for another. Identify the engine first (see *How to operate*), then apply its list. Full catalog in `references/datastore-antipatterns.md` — the top offenders per engine:

**Bad:** the same `SELECT id FROM jobs WHERE claimed_at IS NULL LIMIT 1 FOR UPDATE` polled by 20 workers — every worker serializes on the head row, and throughput collapses to one job at a time.
**Good:** `… ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED` with a lease timestamp — each worker claims a different row; a crashed worker's lease expires and the row is reclaimed. (Keep the locking clause *after* `LIMIT`: Postgres accepts either order, MySQL 8 rejects `FOR UPDATE … LIMIT` with a syntax error, so the portable order is the one to learn.)

- **Relational (Postgres/MySQL)** — long/idle-in-transaction pinning snapshots and draining the pool; `CREATE INDEX` without `CONCURRENTLY` or a `lock_timeout` in migrations; one giant `UPDATE`/`DELETE` instead of batches; `SELECT … FOR UPDATE` queue polling without `SKIP LOCKED`; an ORM `save()` overwriting a concurrent change; assuming every engine raises a serialization failure to retry (§2). (Everything about the query and the index — predicates, projection, N+1, paging, index selection — belongs to `database-best-practices`.)
- **Redis** — treating it as a system of record (async persistence, failover, and `maxmemory` eviction all lose data); mixing cache with locks/jobs under `allkeys-lru` so your queue gets evicted; keys with no TTL; `KEYS *`/`HGETALL`/`SMEMBERS` on big collections blocking the single thread for every client; unversioned cache keys that deserialize into garbage after a deploy; `SET` without `KEEPTTL` silently clearing an expiry; Pub/Sub or `LPOP` on a list used as a queue (at-most-once, no acks — use Streams with consumer groups); `SETNX` locks with no TTL or released with a bare `DEL`.
- **Document (Mongo/Firestore)** — unbounded arrays inside a document; assuming multi-document atomicity; default write concern plus secondary reads (acknowledged writes lost on failover, stale reads); `COLLSCAN` from a missing or wrongly-ordered compound index; a monotonic shard key hot-spotting one chunk; a Firestore document written more than ~1×/sec.
- **Key-value / wide-column (Dynamo/Cassandra)** — modeling before the access patterns are known, so production needs `Scan`/`ALLOW FILTERING`; hot or unbounded partitions; dropping `UnprocessedItems`/throttling errors on write; read-after-write off an (always eventually consistent) GSI.
- **Search (Elasticsearch)** — using it as the primary store; expecting read-your-own-write from a ~1s refresh; `from`/`size` deep paging; dynamic mapping on user-controlled field names; indexing without an alias, so a reindex means downtime.
- **Analytical (ClickHouse/BigQuery)** — OLTP habits in an OLAP store: row-at-a-time inserts ("too many parts"), point lookups, updates as routine writes, `SELECT *` on wide columnar tables, and queries with no partition filter or cost bound.
- **Across all engines** — using a derived store (cache, search index, warehouse) as truth; dual writes with no outbox/CDC to reconcile them (§14); and choosing an engine before anyone can state the queries and the consistency requirement.

### 22. Testing backends — test against the real boundaries
Backend bugs live at the seams — the actual SQL, the transaction, the serialization, the retry. A test that mocks the database asserts your mocks, not your behavior. Test the risky integrations against something real.

**Bad:** unit test that mocks the repository and asserts `save()` was called — passes even when the query is malformed, the constraint is wrong, or the transaction never commits.
**Good:** an integration test against a real database (e.g. testcontainers / an ephemeral instance) that inserts, queries, and asserts the *observed* rows — catches the schema/SQL/transaction bugs mocks can't.
- **Use real infra for your own persistence layer.** Substitute only at true external boundaries (a payment gateway, an external API) — and substitute **your own adapter over the vendor**, never the vendor's own SDK types. A hand-rolled double of someone else's client encodes your guess at their semantics and stays green through a breaking upgrade. `testing-best-practices` §3 owns this rule; don't re-derive it here.
- **Contract-test service boundaries** — verify the API you expose (and the ones you consume) against an agreed schema so a breaking change (§5) is caught before deploy, not by a paging alert.
- **Make time and IO injectable** (`coding-best-practices` §12) so retry/backoff, TTL expiry, and scheduled-job logic are testable without sleeping.
- **Test the failure paths** — the timeout, the duplicate delivery, the concurrent update, the rollback. The happy path rarely pages you; the edges do.

---

## Boundaries, lifecycle & latency

### 23. Webhooks — verify, dedupe, ack fast
An inbound webhook is an unauthenticated POST from the internet claiming to be your payment provider; an outbound one is a promise to someone else's server. Treat inbound as hostile input with a signature, and outbound as a queue job with retries.

**Bad:** `POST /webhooks/payments` parses the body, trusts `event.type`, updates the order, calls two downstream services, then returns `200` — forgeable, replayable, double-applied on the provider's retry, and it times out whenever a downstream is slow (so the provider retries, and it double-applies again).
**Good:** verify the HMAC signature over the *raw* body with the provider's secret; reject stale timestamps; in **one transaction** `INSERT event_id, payload … ON CONFLICT DO NOTHING` into an **inbox** table and return `200`; a relay or worker drains committed inbox rows and processes them idempotently, keyed on the event id.
- **Record and enqueue in the same transaction, or the dedup row eats the event.** Insert-then-enqueue is two steps: if the insert commits and the publish fails, you have already returned `200`, and the provider's retry is deduped away by the very row that was supposed to protect it — the event is gone permanently with no error anywhere. The inbox table *is* the queue; a relay reads from it (§14).
- **Verify before you parse.** Signature over the raw bytes (a re-serialized body won't match), constant-time comparison, a timestamp window against replay, and a per-provider secret from config (§20).
- **Ack fast, process async.** Providers retry on any non-2xx or timeout; the handler's job is "record and acknowledge," not "run the business flow" (§16). When it matters, fetch the authoritative object from the provider rather than trusting the payload alone.
- **Outbound is a job, not a request** — sign it, deliver from a worker with exponential backoff and jitter, dead-letter after N attempts, and let receivers dedupe on your event id (§11, §14, §15).

### 24. State machines & multi-system writes
Any entity with a `status` column is a state machine, and any write that spans two systems (DB + workflow engine, DB + payment provider, DB + search index) has a window where they disagree. Make illegal transitions impossible at the row, and make every in-between state either short-lived or swept.

**Bad:** `order.status = "shipped"; save(order)` from a handler that never checked the previous state — two concurrent requests both move `paid → shipped`, or a late "cancel" overwrites "shipped".
**Good:** `UPDATE orders SET status = 'shipped' WHERE id = $1 AND status = 'paid'` and check `rows_affected` — the guard and the write are one statement; zero rows is a conflict (`409`, or `404` if a re-read finds no row), not a silent overwrite.
- **Encode the allowed transitions once** (a table or map from state → next states) and route every writer through it; derive display state from facts instead of storing a second copy that can drift.
- **Two-phase writes need a sweeper.** Commit your side first with an explicit intermediate state (`pending`), call the other system, then mark `confirmed` or `failed`. A crash in between leaves a row that a scheduled reconciler can find and finish or roll back (§15). A `pending` state with no sweeper is a leak, not a design.
- **Compensate, don't pretend.** If the second system refuses after the first committed, record the failure and run the reverse action (refund, cancel, unindex) as its own idempotent step (§10). That sequence of local commits with compensations is a **saga**; orchestration vs choreography, the pivot step and the isolation trap are in `references/distributed-patterns.md`. Cross-system transactions don't exist; the outbox (§14) is how the first commit drives the second reliably.

### 25. Service lifecycle — start safe, stop clean
A process that takes traffic before its dependencies are ready serves errors; one that dies on SIGTERM mid-request loses writes and leaves jobs half-done. Boot and shutdown are part of the request path's correctness.

**Bad:** the container starts and the load balancer sends traffic at once; the first 200 requests fail because config wasn't validated and the pool isn't open. On deploy, SIGTERM kills the process with 40 requests in flight and a job half-written.
**Good:** validate config and open connections at boot (§20); expose **readiness** (can I serve? dependencies reachable) separately from **liveness** (am I alive?); on SIGTERM flip readiness to failing, stop accepting, drain in-flight requests within a deadline, release job leases, close pools, then exit.
- **Readiness ≠ liveness.** A failing readiness probe pulls the instance from rotation; a failing liveness probe restarts it. Wire a dependency outage to readiness, not liveness, or you restart-loop a healthy process.
- **Bound the drain.** Wait for in-flight work up to a deadline slightly under the orchestrator's kill timeout, then exit — never hang forever, never exit instantly.
- **Singletons need a lease and a fence.** Anything that must run in exactly one process (an embedded scheduler, a workflow engine's timers) holds a leader lease that expires on crash so a replacement takes over — and every write carries the lease's fencing token so a paused, stale holder that wakes up is rejected instead of firing twice (§15; `references/distributed-patterns.md`).

### 26. Tail latency — the p99 is the product
The mean hides the requests users remember. Latency compounds across hops, queues at every bounded pool, and hides in the database as a bad plan or a lock wait. Design and measure for the p99 per endpoint, not the average.

**Bad:** `GET /orders/{id}` at p50 40 ms and p99 3 s — four services called in sequence with no deadlines, the ORM lazy-loads line items per row, and one hot `merchant_stats` row is incremented by every order so writers queue on it.
**Good:** one deadline propagated to every hop with independent calls in parallel; line items eager-loaded in one query; the counter appended as events and aggregated off the write path (a row that guards an invariant, such as a balance, stays an atomic conditional update, §12). Trace one slow request, sort spans by self-time, fix the top span, re-measure.
- **Percentiles per endpoint and per dependency span**, plus pool wait time and event-loop lag — a p99 you can't attribute is one you can't fix (§19).
- **Fewer sequential hops, each with a budget** — fan-out multiplies the tail; the remaining deadline is the next call's timeout (§11, §16).
- **Locks and contention are where database latency hides at runtime** — short transactions, atomic updates over `FOR UPDATE`, no hot-row serialization (§2, §12, §21). When the tail is the *query* rather than the wait, that is `database-best-practices`.
- The full checklist — queueing, warm paths, plan stability, `FOR UPDATE` variants, hot rows, deadlock retry — is `references/latency-and-locks.md`.

---

## Tone

Be direct and constructive. Lead with the highest-impact risks — data corruption, security holes, and unbounded resource use come before style. Skip praise for what's already sound; if the code is solid, say so briefly and point out the one or two things that would make it production-hard.
