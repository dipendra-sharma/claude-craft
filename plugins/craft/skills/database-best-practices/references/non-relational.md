# Non-relational modeling

Same principles as the parent skill, different physics. The two things that change most: **duplication becomes a design tool rather than an exception**, and **the access-path inventory becomes binding rather than advisory**. What never changes: every copy needs an owner and a rebuild path, and a search index or warehouse is never your system of record.

---

## Document stores (MongoDB, Firestore, DocumentDB, Cosmos)

### Embed or reference

The single decision that defines a document model. Embed when the child is **owned by, bounded within, and read with** the parent; reference when any of the three fails.

**Embed** when: the child has no independent identity, the parent is the only reader, the collection is bounded and small, and they change together (which makes the document your consistency boundary — usually the only transaction you get).

```
order = { _id, placed_at, lines: [ {sku, qty, unit_price_cents}, ... ] }
```

Order lines are a textbook embed: never queried without the order, bounded by cart size, and they must be written atomically with it.

**Reference** when: the child is queried on its own, shared between parents, updated on a different cadence, or unbounded.

```
post   = { _id, title, author_id }
author = { _id, name, avatar_url }
```

**The failure mode to fear is the unbounded array.** `user.activity_log: [...]` grows forever, and documents have a hard size limit — 16 MiB in MongoDB — so the model works in testing and hits a wall in production. Long before that ceiling, larger documents cost more RAM and more bandwidth on every read that touches them, which is why MongoDB's own guidance is to reference rather than embed once the embedded data grows without bounds. Any *event*-kind data (parent skill, Part 2) belongs in its own collection keyed by subject and time, never in an array on the entity.

Rule of thumb: if you can't state an upper bound on the array's length, it's a separate collection.

### Duplication with an owner

With no joins, you duplicate to serve reads — an author's name on each post so the feed renders in one query. That's legitimate, and it's still a copy, so it needs the same discipline: one writer owns it, and there's a job that can rebuild every copy from the source. Write down which fields are duplicated where; the thing that rots is the copy nobody remembered existed when the author renamed themselves.

### Schema, when the store doesn't require one

"Schemaless" means the store won't enforce your rules, not that you don't have any. So:

- **Enable native validation** where it exists (JSON Schema validators) — it's the closest thing to a constraint you have.
- **Put required-field, type and range rules in one write-boundary layer** every writer passes through. Three services each with their own idea of valid is how a collection ends up with five shapes.
- **Decide the missing-vs-null convention** and enforce it. A field absent and a field set to null are different states in query semantics; pick one meaning and stick to it.
- **Version your documents** (`schema_version`) and write tolerant readers that cope with old shapes. Then choose lazily-migrate-on-read or a backfill — but choose, rather than discovering the history in production.

### Indexes

Compound index field order follows the same equality-then-range-then-sort rule as relational, and the same cost model applies: every index is a maintained copy that taxes writes.

**Partial indexes are not a general document-store feature — check before designing around one.** MongoDB has them (`partialFilterExpression`), and they are the right tool for the soft-delete and operational-queue cases. Firestore does **not**: it offers single-field index *exemptions*, which exclude fields rather than rows. Cosmos DB offers indexing-policy path includes/excludes, also not a row predicate.

---

## Key-value and wide-column (DynamoDB, Cassandra, Bigtable, HBase)

### The key is the schema

Here the access-path inventory isn't advisory — it's the design. The partition key determines what you can query and how load distributes; the sort key determines what ranges and orderings you get. Get it wrong and you don't add an index later, you rewrite the dataset.

So invert the usual order: **write the queries first, then design the key to serve them.** For each access path, name the exact partition key value the caller will have in hand. If the caller doesn't have it, that path doesn't exist.

### Choosing the partition key

Two opposite failure modes:

- **Too coarse → hot partition.** A monotonic timestamp puts every write on the newest partition; `status = 'pending'` puts every job in one. Throughput collapses to one partition's limit no matter what you provisioned.
- **Too fine → scatter.** If a common read has to fan out across every partition, you've built a distributed full scan.

Fixes for hot keys: add a dimension you already have (tenant, region, entity id), or bucket deliberately (`date#shard`) accepting a bounded fan-out on read. Always sanity-check the highest-cardinality *and* highest-traffic value — the tenant with 200x everyone else's volume is the one that finds your hot partition.

**Size the partition, not just the key.** In Cassandra, target **under 100 MB on disk per partition**, with roughly **100,000 rows** as a secondary proxy — 100 MB is the binding constraint and the row count is just an easier thing to estimate. Past that, read latency and compaction cost climb sharply. The remedy is bucketing: add a time or shard component to the partition key. Verify with `nodetool tablestats` ("Compacted partition maximum bytes") rather than guessing. And if a query needs `ALLOW FILTERING`, the model is wrong, not the query.

### Duplication is the model

With no joins and one index per access path, you store the same fact several ways — one item shape per query. Cassandra practitioners say it plainly: one table per query. In DynamoDB the same idea appears as **single-table design**, where several entity kinds share a table and the key is generic (`PK`/`SK` holding values like `ORDER#123` / `LINE#1`), letting one query fetch a parent and its children together.

Two cautions. First, single-table design is an optimization for known, stable access paths — it trades flexibility and legibility for round-trips, and it's a poor default while the access paths are still moving. Second, all this duplication means writes fan out; the write amplification is the price of the read performance, and it must be paid by *one* owner with a rebuild path.

### Secondary indexes

Treat them as projections you pay for, not as free flexibility. In DynamoDB a global secondary index is maintained asynchronously and consumes write capacity from *the index*, not the base table — so an under-provisioned index throttles writes to the table itself. Its reads are eventually consistent, meaning read-after-write against a GSI can return stale data. And because a GSI is organised by its own key, it carries its own hot-partition risk. Prefer designing the primary key to serve the dominant path, and use a secondary index for genuinely secondary ones.

**Local secondary indexes are a one-way door.** An LSI must be defined at table creation and can never be added, dropped, or changed afterwards; it shares the base table's partition key. Worse, **any table carrying an LSI caps each item collection at 10 GB** — once one partition-key value's items plus its LSI entries cross that, writes to it fail with `ItemCollectionSizeLimitExceededException` and the only fix is a migration. If an item collection could grow without bound, use a GSI instead.

**The numbers that constrain the model**, because each one changes a design decision: **400 KB** max item size (decides embed vs. an S3 pointer), **20 GSIs** and **5 LSIs** per table by default, **10 GB** per item collection on any LSI table. Capacity is billed in **1 KB per WCU** and **4 KB per RCU** (half an RCU for eventually-consistent reads) — that is what "capacity units scale with item size" actually means, and it's why a fat item costs on every single read.

### What you don't get

No cross-item transactions in the general case (limited ones exist and are bounded), no referential integrity, no uniqueness across partitions except via the primary key itself. Uniqueness of a non-key field is typically implemented as a separate item whose key *is* that value, written conditionally — which is a modeling decision, not a constraint.

---

## Search engines (Elasticsearch, OpenSearch, Algolia)

A search index is **always a projection, never a source of truth.** It has no constraints and no transactions, and you cannot change the type of an already-mapped field: adding new fields is free, but changing one means building a new index, reindexing into it, and swapping an alias over. Treat that as a normal operation rather than an incident. (Runtime fields and field aliases are the escape hatches when you need to avoid a full reindex.)

Model it for the query, not the domain: flatten the joins you'd otherwise do at read time, denormalize whatever the result page displays, and accept the duplication because the whole dataset is rebuildable by definition. Fields exist to be *searched* (analyzed text), *filtered* (keyword/numeric), or *returned* — decide which per field, since analyzing a field you only filter on is wasted work and the reverse simply doesn't match.

Keep the feed one-directional: primary store → change capture or outbox → index. Dual-writing to database and index is the canonical way to get a permanently divergent index.

---

## Columnar and warehouse (BigQuery, Snowflake, Redshift, ClickHouse)

Different job: this layer answers analytical questions over history, and it's downstream of everything above.

**Grain is still the first question**, and it's the most common warehouse bug — a fact table documented as "one row per order" that is actually one row per order line will double every revenue number that joins to it. State the grain, then test it with a uniqueness check on the claimed key.

**Facts and dimensions map onto the parent skill's kinds**: fact tables are *event* datasets (append-only, time-partitioned, unbounded), dimensions are *entity* and *reference* datasets. Slowly-changing dimensions are the validity-range pattern — when the business asks "what did this customer's segment look like when they ordered?", you need the versioned dimension, not the current one.

**Physical layout is the main performance lever**: partition by the time column you filter on, cluster or order by the columns you filter next. Columnar stores read only referenced columns, so wide tables are cheap and `SELECT *` is expensive — the opposite instinct from row stores.

**Design for late-arriving and corrected data.** Events show up out of order and get restated; a model that assumes append-only-and-never-wrong will quietly produce numbers that don't reconcile. Idempotent loads keyed on a natural event id let a reprocessed batch be safe.

If the request is specifically to design a BI star schema, that's outside the parent skill's scope — it's a distinct discipline with its own literature.
