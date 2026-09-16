# Tail latency and lock contention

The mean lies. A p50 of 40 ms with a p99 of 3 s means one request in a hundred — and one multi-call page load in ten — is slow enough to feel broken. This is the checklist for the p99: how latency compounds, where it hides in the database, and how to stop transactions waiting on each other. Parent §1, §4, §6, §12, §16, §17, §21 and §26 carry the rules; this is the deeper pass.

---

## 1. Think in percentiles and budgets

- **Measure percentiles per endpoint, not averages.** Histograms (p50/p95/p99/p99.9), split into wait time vs service time, with one span per dependency in the trace (parent §19). A p99 you can't attribute to a span is a p99 you can't fix.
- **Fan-out amplifies the tail.** A request that touches N dependencies inherits roughly the worst of N draws: ten calls each slow 1% of the time make about 10% of requests slow. Cut sequential hops first; run independent calls in parallel second (parent §16).
- **Hand each hop a budget.** The request's deadline minus time already spent becomes the timeout for the next call, and it is propagated (header, gRPC deadline, context). A dependency given 30 s when the client gave up at 2 s is wasted work.
- **Queueing is latency.** Every bounded pool — connections, workers, the event loop — has a wait line, and wait time grows non-linearly once utilization passes roughly 70–80%. Pool wait time and event-loop lag are first-class metrics; add capacity or shed load before saturation (parent §4, §16).
- **Warm paths stay warm.** Cold starts, JIT warm-up, empty caches, cold connection pools and TLS handshakes all live in the tail. Keep-alive and HTTP/2 to downstreams, pools opened at boot, DNS cached; on serverless, provisioned concurrency or an accepted tail.
- **GC and stop-the-world pauses** show up as periodic p99 spikes with no slow query behind them. Watch pause metrics; reduce allocation on the hot path (stream instead of materialize, fewer intermediate objects) before tuning the collector.

---

## 2. Database latency that is *not* the query

**Query and plan latency belongs to `database-best-practices`** — reading `EXPLAIN`, sargability, which indexes should exist, composite column order, covering and partial indexes, keyset vs `OFFSET`, `COUNT(*)` cost, and what a read costs in bytes. Load that skill when the answer is "the query or the index is wrong." What stays here is the runtime and operational layer around it:

- **Stats and bloat.** A good plan goes bad when statistics are stale or the table is bloated with dead tuples: `ANALYZE` after bulk loads, autovacuum tuned for hot tables, `n_dead_tup` watched. A plan flip is the classic "it got slow overnight and nothing deployed."
- **Prepared statements and plan caching** save parse and plan time on hot queries — but a generic plan for skewed data (one tenant holds 90% of rows) is wrong for everyone else. When one parameter value is slow, check `plan_cache_mode` (Postgres) or parameter sniffing (SQL Server).
- **Sorts and hashes that spill to disk** (`Sort Method: external merge`) are tail latency. `work_mem` raised for that statement only is the runtime lever; the index that removes the sort is `database-best-practices`.
- **Round-trips, not just queries.** N small fast queries in sequence are one slow request regardless of how good each plan is. Batch them or run independent ones concurrently on separate connections. Multi-row `INSERT … VALUES` or `COPY` for bulk writes.
- **Move heavy reads off the primary.** Replicas for reports and lists (read-your-writes routed to the primary), materialized views for dashboards, a search engine for text search (`datastore-antipatterns.md` §5) — a routing decision, not a query decision.
- **`statement_timeout` at the role or pool level** so a runaway query dies instead of holding a connection and a snapshot (`datastore-antipatterns.md` §7).

---

## 3. Locks — hold less, hold shorter, hold nothing under a network call

Under MVCC readers never block writers and writers never block readers; almost every lock wait you see is writer-vs-writer, DDL, or an explicit share lock (`FOR SHARE`, `LOCK TABLE`, a foreign-key check). Contention, not CPU, is what makes a healthy database feel slow.

- **Shortest possible transaction.** Open late, commit early; compute and validate before `BEGIN`; never await an external call, a queue publish or user input inside (parent §2, §16). Set `idle_in_transaction_session_timeout`.
- **Lock the row, not the table.** Explicit `LOCK TABLE`, unindexed foreign-key checks that scan, and DDL without `lock_timeout` are table-wide waits (`datastore-antipatterns.md` §1). Every migration statement runs under `SET lock_timeout` and retries.
- **Prefer the atomic statement to the lock.** `UPDATE … SET stock = stock - 1 WHERE id = $1 AND stock > 0` does in one statement what `SELECT … FOR UPDATE` plus `UPDATE` does in two, with no lock held across a round-trip (parent §12).
- **Optimistic before pessimistic.** A `version` column and `UPDATE … WHERE version = $expected` costs nothing when uncontended. Use `SELECT … FOR UPDATE` only where retries would be constant and expensive — and then hold it for microseconds.
- **`FOR UPDATE` variants matter.** `FOR NO KEY UPDATE` when you won't change the key (child inserts' FK checks proceed); `SKIP LOCKED` for queue-style claiming so workers don't line up on one row; `NOWAIT` when waiting is worse than failing.
- **Hot rows are the real contention.** A counter row, a parent row every child insert touches, a stats row every order increments: all writers serialize on it. For counters and statistics: shard into N rows and sum; append an event row and aggregate asynchronously (parent §24); batch increments in the app and flush; make the parent update rarer or move it off the write path. A row that guards an invariant — a balance, a stock level — stays one atomic conditional update (parent §12): accept the serialization, keep that transaction tiny, and never trade the invariant for throughput.
- **FK locks on hot parents.** Inserting a child takes a `KEY SHARE` lock on the parent row; a concurrent `FOR UPDATE` or key-changing `UPDATE` on that parent waits on it. Don't update parent rows in the same transaction as bulk child inserts; use `FOR NO KEY UPDATE`.
- **Consistent lock order and deadlock retry.** Two paths taking rows in different orders deadlock; sort ids before locking (parent §12). Every engine aborts one transaction on a deadlock (Postgres `40P01`, MySQL 1213, SQL Server 1205), so wrap the whole transaction in a bounded retry. **Postgres additionally** aborts with a serialization failure (`40001`) under `REPEATABLE READ`/`SERIALIZABLE` — InnoDB and SQL Server do not, so don't port a Postgres retry-on-`40001` assumption to them (parent §2).
- **Long readers pin snapshots.** A ten-minute report on the primary stops vacuum from reclaiming dead tuples for everyone, and bloat is future latency. Moving it to a replica does not make the snapshot free: with `hot_standby_feedback = on` the standby's long query delays vacuum **on the primary** and produces the same bloat; with it off, the query is cancelled once `max_standby_streaming_delay` is exceeded. Pick deliberately — a dedicated reporting replica with feedback off and a generous delay, or a separate copy, not the HA standby — and put a `statement_timeout` on it either way.
- **Advisory locks** (`pg_advisory_xact_lock(key)`) serialize an application-level critical section without locking rows — cheap when the invariant is "one at a time per tenant" rather than a row. Use the **transaction-scoped** function, never session-scoped `pg_advisory_lock`: session-level advisory locks do not work through PgBouncer transaction pooling, so the lock outlives your request on a connection another request now owns. The key space is one global 64-bit namespace per database — allocate a documented range per feature rather than hashing a string and hoping.
- **Watch the waits, not the CPU.** `pg_stat_activity` with `wait_event_type = 'Lock'`, `pg_locks`, `pg_blocking_pids()`, and lock-wait alerts; MySQL `performance_schema` and `SHOW ENGINE INNODB STATUS`. Lock wait time is a latency metric.

---

## 4. The request path at the p99

- **Do less on the request path.** Anything the response doesn't need — emails, analytics, secondary indexes, third-party notifications — goes to a queue after commit (parent §14, §16); anything long returns `202` with a status handle.
- **Cache the expensive and the hot** (parent §17): request-scoped memoization for repeated lookups inside one request, an in-process cache for immutable reference data, a shared cache for hot reads — each with single-flight on miss.
- **Stream and shape responses.** Sparse fieldsets, pagination, compression, streaming for large payloads (`http-semantics.md` §7). Serializing a 5 MB JSON graph is CPU on the event loop.
- **Locality.** Same *region* as the database, always — a cross-region round-trip is 60–250 ms depending on the pair, and a chatty ORM makes twenty of them. Same *zone* saves ~1 ms and costs you AZ-failure tolerance, since the service now dies with its database's AZ and can't survive a failover to the standby; take it only in a single-AZ deployment you have already accepted. Cutting round-trips (parent §1) beats chasing the last millisecond.
- **Rank fixes by span.** Trace one slow request, sort spans by self-time, fix the top one, re-measure. Guessing ("it's probably the DB") is how weeks disappear.
