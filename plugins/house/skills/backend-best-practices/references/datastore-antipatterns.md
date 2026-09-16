# Datastore anti-pattern catalog

Per-engine failure modes to recognize in review and avoid when writing. Parent skill §21 carries the top offenders; this is the full list. Each entry is **anti-pattern → what breaks → what to do instead**.

**The model *and the query* go to `database-best-practices`.** This catalog is about *operating* a store at runtime: transactions, isolation, locking and blocking, DDL, replication, pool and client behaviour. What the model should be — datasets, grain, identity, normalization, which indexes and partition keys should exist — **and how any query is written, shaped, planned or costed** belongs to that skill. The two are meant to be loaded together on data work.

Rules that hold for every engine (don't re-derive them per section): parameterize queries, bound every result set, time out every call, keep transactions short (parent §1, §2, §4, §6). Anything about how a query is written, indexed or costed is `database-best-practices` — this catalog is runtime behaviour only.

Entries marked **[blocks]** stall other work — the whole engine, a partition, or every worker in your service — rather than just being slow for the caller. They're the ones that turn a bad query into an outage; see parent §16.

---

## 0. Choosing a store

- **Picking by familiarity or hype instead of access pattern.** "We'll use Mongo/Dynamo/Redis" before anyone can state the queries, the consistency requirement, and the write rate. → Write the access patterns down first; a relational DB is the correct default until a pattern proves it can't serve it.
- **Using a derived store as the system of record.** Cache, search index, or warehouse treated as truth. They are rebuildable projections; if you can't rebuild them from the primary, you have no backup. → One system of record; everything else derived and reproducible.
- **Dual writes to two stores.** `db.save(x); search.index(x)` — a crash or a failed second call diverges them permanently, and nothing ever reconciles. → Outbox or CDC from the primary (parent §14).
- **Polyglot sprawl.** Five engines, each with its own failure modes, backups, and on-call knowledge, for one team. → Fewer stores, better understood. Postgres does JSON, queues (`SKIP LOCKED`), full-text, and geo well enough to defer a second engine for a long time.
- **Not knowing the store's consistency model.** Coding read-after-write against an eventually consistent replica/secondary/GSI. → Know it explicitly; route read-your-own-write to the primary.
- **Untested restores.** Backups that have never been restored are a hypothesis, not a backup. → Restore-drill periodically; know the RPO/RTO you actually have.

---

## 1. Relational (Postgres / MySQL / SQL Server)

### Schema modeling
Owned by the `database-best-practices` skill, not this catalog. EAV and JSON-as-the-model, missing foreign keys, everything-nullable, native `ENUM`, float money, naive timestamps, soft-delete uniqueness, tenant scoping and blobs stored in rows are all covered there — see its `references/relational.md` and `references/engine-map.md`. Load it whenever the schema itself is in question. The sections below are about running queries, indexes and transactions against a schema that already exists.

### Query shape and indexing
Both are owned by `database-best-practices`, not this catalog — sargability and non-usable predicates, `SELECT *` and projection, N+1 and round-trip count, `COUNT(*)` cost, deep `OFFSET` paging and keyset, fan-out joins papered over with `DISTINCT`, oversized `IN` lists, index selection, composite column order, redundant indexes, the missing index on a foreign-key child, and the write cost of each index. Load it whenever the fix is "the query or the index is wrong." What remains in this file is what happens at *runtime* around a query that already exists: locks, transactions, DDL, replication and pool behaviour.

### Transactions & concurrency
- **Long/idle-in-transaction.** **[blocks]** A transaction held open across an HTTP call or user think-time pins the oldest snapshot: dead tuples can't be vacuumed, locks pile up, the pool drains. → Open late, commit early; never await an external service inside one.
- **Read-modify-write across statements.** (parent §12) → One atomic `UPDATE`, or optimistic locking on a `version` column.
- **Retrying serialization failures nowhere — and assuming every engine raises them.** **Postgres** at `REPEATABLE READ`/`SERIALIZABLE` *will* abort transactions with `40001`, and code that doesn't retry surfaces it as a random 500. **InnoDB** at `REPEATABLE READ` does **not** abort: a concurrent `UPDATE`/`DELETE` can affect rows committed after your snapshot, so a read-then-write lost update fails *silently* — worse than an abort, because nothing surfaces. **SQL Server** `SERIALIZABLE` is range locks, so you get blocking and deadlocks (1205), never `40001`. → Bounded retry around the whole transaction on Postgres; on InnoDB and SQL Server use an atomic conditional `UPDATE` or a `version` column, because there is no error to retry (parent §2).
- **`SELECT … FOR UPDATE` polling as a queue without `SKIP LOCKED`** **[blocks]** — every worker serializes on the same head row. → `FOR UPDATE SKIP LOCKED` with a claim timestamp/lease, or a real broker (parent §21).
- **DDL in the hot path / unbounded lock waits.** **[blocks]** An `ALTER TABLE` waiting on a lock queues every subsequent query behind it — an instant outage. → `SET lock_timeout` (and `statement_timeout`) in migrations; retry.
- **`CREATE INDEX` without `CONCURRENTLY`** **[blocks]** (Postgres) locks writes for the build. → `CONCURRENTLY`, outside a transaction, and check for an `INVALID` index afterwards.
- **One giant `UPDATE`/`DELETE`.** **[blocks]** Table-wide locks, bloat, replication lag. → Batch by primary-key ranges with a commit per batch.
- **Assuming DDL is transactional.** True in Postgres, *not* in MySQL — a failed multi-statement MySQL migration leaves it half applied. → One DDL change per migration; make each idempotent/resumable.
- **Reading your own write from a replica.** → Route post-write reads to the primary, or gate on replication position.

### ORM-specific
- **Loading an entity, mutating, and `save()`ing the whole row.** Overwrites fields another request changed in between — a lost update the ORM hides from you. → Targeted `UPDATE … SET` of changed columns, plus a `version` check (parent §12).
- **Migrations auto-generated and merged unread.** The generator will happily emit a destructive rename or a blocking index build. → Read the SQL every time; check it against parent §3.
- **Lazy loading during serialization and unbounded `.all()`** are query-shape problems → `database-best-practices`. The ORM just makes them invisible until production.

---

## 2. Redis (and Memcached-style caches)

### Durability & role
- **Treating Redis as a system of record.** Default persistence is asynchronous, failover can lose acknowledged writes, and `maxmemory` eviction will delete your "data" when memory runs out. → Truth in the primary DB; Redis holds derived, rebuildable state. If you genuinely need durability, know your `appendfsync`/replication guarantees and accept the remaining window.
- **Mixing cache and non-cache data in one instance.** With `allkeys-lru`, memory pressure evicts your queue jobs, locks, and rate-limit counters along with cache entries. → Separate instances/databases per role, or `volatile-*` policies with TTLs only on cache keys.
- **No `maxmemory` / no eviction policy.** The instance grows until the OOM killer resolves it. → Set both, deliberately.
- **No TTL on anything.** Memory grows monotonically and nothing is ever reclaimed. → Every cache/session/lock key gets a TTL; the exceptions should be countable on one hand.
- **`SET key value` on a key that had a TTL.** Silently clears the expiry, turning a cache entry into a permanent one. → `SET … KEEPTTL` (Redis ≥ 6.0), or re-apply the TTL explicitly on older servers.

### Blocking the single thread
Redis executes commands on one thread: any O(N) command stalls *every* client.
- **`KEYS *` in production** **[blocks]** (and `SMEMBERS`/`HGETALL`/`LRANGE 0 -1` on a huge collection). → `SCAN`/`HSCAN`/`SSCAN` with a cursor, or keep a paginated index structure.
- **Big keys.** **[blocks]** A multi-megabyte hash or a million-element list: slow reads, slow replication, slow expiry, uneven cluster slots. → Split by a shard/date suffix; cap collections (`LTRIM` after `LPUSH`).
- **Long-running Lua / `FUNCTION` calls.** **[blocks]** A script is atomic — and blocks everyone for its duration. → Keep scripts to a handful of commands; no unbounded loops.
- **`FLUSHALL`/`FLUSHDB` as cache invalidation** **[blocks]**, from application or ops scripts. → Key-prefix versioning (below) or targeted `UNLINK`.
- **`DEL` on a huge key.** **[blocks]** Frees memory synchronously. → `UNLINK`.

### Access patterns
- **Redis N+1.** A loop of `GET`s, one round-trip each, inside a request. → `MGET`, a pipeline, or a single hash.
- **Read-modify-write from application code.** `GET counter` → increment in app → `SET counter` loses updates under concurrency. → `INCRBY`/`HINCRBY`, `WATCH`+`MULTI`, or Lua.
- **Cluster-unaware multi-key ops.** `MGET`/`MULTI` across keys in different hash slots errors out. → Hash tags (`user:{123}:profile`) to co-locate, or per-key calls.
- **Connection per request.** Handshake cost and connection exhaustion. → A pooled client with connect/read timeouts and a bounded pool.
- **No client-side timeout.** **[blocks]** A blocked Redis becomes hung application workers. → Timeouts on every call; treat cache as optional (fail open to the DB — while remembering that a total cache outage then hits the DB with full traffic, so keep DB-side limits).

### Keys & payloads
- **Unversioned key names.** After a deploy changes the cached shape, old entries deserialize into garbage or throw. → Embed a schema version and the identifying inputs: `v3:user:profile:{id}`. Bumping the prefix invalidates everything atomically.
- **Language-native serialization** (pickle, Java serialization, PHP `unserialize`) in cache values. Cross-version breakage, and a deserialization RCE surface if anything untrusted can write. → JSON/MessagePack/protobuf with an explicit schema.
- **Per-user data under a shared key** (parent §17) — the classic auth leak. → Include the user/tenant in the key.
- **Unbounded key cardinality.** A key per request id with no TTL, or rate-limit keys per IP+path+minute never expiring. → TTL sized to the window.

### Coordination
- **Naive `SETNX` lock with no TTL.** **[blocks]** The holder crashes; the lock is held forever. → `SET key token NX PX ttl`.
- **`DEL` to release someone else's lock.** After a TTL expiry the original holder deletes the *new* owner's lock. → Store a unique token and release with a compare-and-delete Lua script; re-check ownership before acting.
- **Using a Redis lock to protect a correctness-critical invariant.** Expiry, clock skew, and failover can grant two holders; Redlock doesn't close this. → Enforce the invariant in the database (atomic `UPDATE`, unique constraint); use Redis locks for best-effort coordination and deduplication only (parent §12).
- **Pub/Sub as a message queue.** At-most-once, no persistence, no acks: every subscriber disconnect loses messages. → Redis **Streams** with consumer groups (`XADD`/`XREADGROUP`/`XACK`, plus a `XAUTOCLAIM` path for stuck entries) or a real broker.
- **Keyspace notifications as a reliable event bus.** Same fire-and-forget semantics as Pub/Sub, plus events dropped under load. → Explicit events via Streams/outbox.
- **`LIST` as a queue with `LPOP`.** **[blocks]** The message is gone the instant it's read — a crashed worker loses it, and there's no retry or DLQ. → Streams with acks, or a broker with visibility timeouts (parent §14, §15).
- **Sessions with no TTL or no rotation on privilege change.** → TTL + explicit invalidation on logout/password change.

---

## 3. Document stores (MongoDB, Firestore, DocumentDB)

- **Unbounded array growth inside a document.** Comments/events appended forever hit the document size limit (16 MB in Mongo), rewrite the whole document per update, and bloat array indexes. → A separate collection referencing the parent; embed only bounded, read-together data.
- **Embed/reference chosen by habit.** → Decide per access pattern: embed what's always read together and bounded; reference what's large, shared, or independently queried.
- **Rebuilding relational joins with `$lookup` on every read.** → Denormalize the few fields you display, or accept that this workload wanted a relational DB.
- **No schema validation.** Six shapes of the same document accumulate, and every reader needs defensive branches. → JSON-Schema validators / Firestore rules, plus a migration path per shape change.
- **Index selection and compound key order → `database-best-practices`.** A `COLLSCAN` in `explain()` means the model's access path is wrong, not that the driver misbehaved.
- **Assuming multi-document atomicity.** Only single-document updates are atomic by default. → A multi-document transaction (with retry on `TransientTransactionError`), or restructure so the invariant lives in one document.
- **Assuming `w: 1`, or missing the P-S-A trap.** The implicit default write concern has been `w: "majority"` since MongoDB 5.0, so adding it everywhere is usually a no-op — *except* in replica sets where data-bearing voting members don't exceed the voting majority (the classic 3-node Primary-Secondary-Arbiter), where it silently drops to `{ w: 1 }` and an acknowledged write can be rolled back on failover. → Check your topology; state `w: "majority"` explicitly on anything that matters rather than inheriting it. Secondary reads remain stale — primary reads for read-your-own-write.
- **`find()` with no projection or limit.** Ships whole documents you discard.
- **Unanchored / case-insensitive `$regex`** as search. → Anchored prefixes with an index, a text index, or a search engine.
- **Monotonically increasing shard key** (timestamp, ObjectId). All writes land on one chunk. → Hashed or composite shard key chosen from the write pattern.
- **`double` for money.** → `Decimal128`.
- **Firestore-specific:** a single document updated more than ~1×/sec (write contention) → sharded counters; unbounded collection-group queries with no index or limit → paginate with cursors; security rules that only check `auth != null` → check ownership per document.

---

## 4. Key-value & wide-column (DynamoDB, Cassandra, Bigtable)

- **Designing the schema before the access patterns.** These engines answer only the queries you designed a key for. → Enumerate queries first, then model keys/tables per query, duplicating data as needed.
- **`Scan` (Dynamo) or `ALLOW FILTERING` (Cassandra) in production.** **[blocks]** Reads the whole table to answer one question; cost and latency scale with data, not results. → A GSI/LSI or a purpose-built table; `ALLOW FILTERING` is a development smell, not a fix.
- **Hot partition key.** **[blocks]** Low-cardinality (`status`, `country`), a date bucket everyone writes to today, or one whale tenant. → Add a suffix/shard component; spread writes.
- **Unbounded partitions.** A Cassandra partition growing past ~100 MB / hundreds of thousands of rows makes reads and compaction pathological. → Bucket by time or sequence in the partition key.
- **Cassandra as a queue.** **[blocks]** Delete-heavy workloads generate tombstones that reads must scan through until `gc_grace_seconds` passes. → A real broker.
- **High-cardinality Cassandra secondary indexes.** Fan out to every node per query. → A denormalized table per query pattern, or SASI/materialized views with eyes open.
- **Expecting transactions.** Lightweight transactions (`IF NOT EXISTS`) are Paxos round-trips — correct but slow, and not a general transaction. Dynamo `TransactWriteItems` is capped and doubles cost. → Design idempotent, single-partition writes.
- **Ignoring throttling and partial failures.** `BatchWriteItem` returns `UnprocessedItems`; a provisioned table returns `ProvisionedThroughputExceeded`. Dropping either loses writes silently. → Retry unprocessed items with exponential backoff and jitter (parent §11).
- **Strongly-consistent reads everywhere** (double cost) — or eventually-consistent reads *and* GSI reads where read-after-write is required (GSIs are always eventually consistent). → Choose per call site, and never read-after-write off a GSI.
- **Item/row growth to the limit** (400 KB Dynamo) with blobs inline. → S3/object storage + pointer.

---

## 5. Search engines (Elasticsearch / OpenSearch)

- **Using it as the primary store.** No transactions, lossy on split-brain, and a mapping change means a reindex. → Derived index rebuildable from the DB.
- **Expecting read-your-own-write.** **[blocks]** Near-real-time means ~1s refresh; a `?refresh=true` per write destroys throughput. → Read the just-written entity from the DB; let search catch up.
- **`from`/`size` deep pagination.** Cost grows with the offset and there's a hard `max_result_window`. → `search_after` with a PIT, or `scroll` for exports.
- **Dynamic mapping on user-controlled field names.** Mapping explosion and type conflicts that reject documents forever after. → Explicit mappings, `dynamic: strict`, and flattened/nested types for open-ended data.
- **Indexing directly against a concrete index name.** No way to reindex without downtime. → Always read/write through an alias; reindex into a new index and flip the alias atomically.
- **One unbounded index for time-series data.** → Time-based indices/data streams with ILM.
- **`query_string` built from user input.** A query-DSL injection and a trivially expensive query (leading wildcards, huge boolean expansion). → Structured DSL with bound values, or `simple_query_string` with restricted flags.

---

## 6. Analytical / columnar (ClickHouse, BigQuery, Snowflake, Redshift)

- **Treating an OLAP store as OLTP.** **[blocks]** Row-at-a-time inserts, point lookups by id, and per-row updates are the workloads these engines are worst at. ClickHouse specifically: single-row `INSERT`s create a part each, and merges can't keep up ("too many parts"). → Batch inserts (thousands of rows / seconds of buffering) or `async_insert`; serve point lookups from the OLTP store.
- **Updates and deletes as normal operations.** ClickHouse mutations rewrite parts asynchronously; warehouse `UPDATE`s rewrite micro-partitions. → Append-only with `ReplacingMergeTree`/`AggregatingMergeTree` or dedup-on-read by version; never rely on `FINAL` for hot user-facing queries.
- **Sort key, partitioning and column projection → `database-best-practices`** (its columnar section). On a warehouse those are the bill, and they are modeling decisions, not runtime ones.
- **No dedup strategy for at-least-once ingestion.** Every pipeline replay double-counts. → An idempotency/version column plus a dedup step (parent §10, §14).
- **Serving a user-facing API straight off the warehouse** with no cache, no concurrency cap, and no query cost limit. → Precomputed aggregates in the OLTP store or a cache; bound concurrency and per-query cost.
- **Overpartitioning.** A partition per hour per tenant creates millions of tiny parts/files and destroys read performance. → Coarser partitions (day/month) plus ordering keys.
- **Unbounded ad-hoc query cost.** → Byte/slot limits, `maximum_bytes_billed`, per-user quotas, mandatory partition filters (`require_partition_filter`).

---

## 7. Operational hygiene (all engines)

- **One credential for everything.** Migrations, app reads/writes, and analytics sharing a superuser. → Separate least-privilege roles per purpose (parent §18).
- **No slow-query visibility.** → `pg_stat_statements` / slow query log / profiler enabled, with the top offenders reviewed regularly.
- **No per-statement timeout.** **[blocks]** One pathological query holds a connection until someone notices. → `statement_timeout`/`max_execution_time` set at the role or connection level.
- **Pool sized by guesswork** **[blocks]** (parent §4), or a serverless deployment opening a pool per invocation → a connection proxy/pooler.
- **Schema drift between environments.** Hand-applied production changes that no migration file records. → Migrations are the only writer of schema; verify with a diff in CI.
- **Test data volume unlike production.** A plan that's fine on 1,000 rows is a seq scan on 100 million. → Benchmark against production-scale data before calling a query fast.
