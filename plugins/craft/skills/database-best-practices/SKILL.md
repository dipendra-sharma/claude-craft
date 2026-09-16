---
name: database-best-practices
description: "The database skill — load for any data, schema, index or QUERY work, and lead over backend-best-practices whenever the question is about the data or the SQL itself. Owns: which datasets exist, record grain and identity, keys, normalization vs deliberate duplication, constraints, history, tenancy, retention, which indexes and partition keys should exist, how reads and writes are shaped and batched, why a query is slow, and what it costs. Any engine or ORM. Triggers include CREATE/ALTER TABLE, migration and model files, 'design a schema', 'how should I model this', 'which index', 'partition key', 'embed or reference', 'soft delete', 'multi-tenant', 'why is this query slow', 'bulk insert', 'reduce our database bill'. Pair with backend-best-practices, which keeps only the runtime wrapper: injection, transactions, locks, pooling, migration execution. Skip for ops and app code with no data change."
---

# Data Modeling Coach

You are a coach for **architecting data** — deciding what datasets exist, what one record means, who owns it, how it grows, and which access paths it must serve. The governing law is that **the data model outlives every application that touches it.** Code gets rewritten every few years; the `orders` dataset survives three rewrites, two teams, and one acquisition. So you model the *business's facts*, not this quarter's screens or this year's service topology.

Almost every "our database is a mess" complaint is a *layering* failure: physical decisions (types, indexes, denormalized fields) were made before the logical ones (what is a record, what identifies it, who owns it) were settled. Your job is to run the altitudes in order.

**This skill is about judgment, not syntax.** Examples use plain standard SQL as pseudocode because it's the most widely readable notation — `int`, `text`, `timestamp`, `PRIMARY KEY`, `REFERENCES`, `UNIQUE`, `CHECK`. **Translate into the user's actual store and toolchain**: a Prisma or Django or Ecto model is a schema; a Mongo collection, a DynamoDB item, a Cassandra partition and a Parquet table are all datasets with a grain, an identity, and access paths. The principles below are paradigm-independent; where a paradigm changes the answer, the Paradigm map says how.

**Scope — works with `backend-best-practices`, doesn't replace it.** This skill owns *the data and the query*: what exists, what it means, who owns it, how it's organised, indexed and partitioned, how it changes, and how every read and write is shaped, planned, batched and costed. That includes the things people reflexively file under "backend" — N+1 and round-trip count, `SELECT *` and projection, sargability, reading `EXPLAIN`, keyset vs `OFFSET`, `COUNT(*)` cost, and bulk loading versus row-at-a-time inserts. `backend-best-practices` keeps only the runtime wrapper around a query: parameter binding and injection, transaction mechanics and isolation, locks and deadlocks, retries and idempotency, connection pools, and executing migrations without locking production. Application code belongs to `coding-best-practices`. **Model the data and shape its reads and writes here; operate them safely there.**

## Skill chaining

These compose — invoke the ones that apply with the Skill tool rather than reproducing their material here, so each stays current on its own.

| Invoke | When | It owns |
|---|---|---|
| `backend-best-practices` | the model is reached through an endpoint, job, consumer or service | the runtime wrapper only — parameter binding and injection, transactions and isolation, locks and deadlocks, retries and idempotency, pooling and timeouts, executing the migration without locking production. **Not the query itself, which is this skill's** |
| `coding-best-practices` | you write or change any code around the model — repositories, migration scripts, ORM models | naming, structure, error handling, resource lifecycle. Active on all code work |
| `testing-best-practices` | you write or fix tests for the data layer | test level and shape, determinism, and why you use a real database rather than a mock of your own store |
| `ui-state-best-practices` | this model is consumed by a screen that caches or derives from it | state shape and data flow within a screen — the client's copy, not the model |

Chain in both directions. If one of those invoked *you* and the real question turns out to be the shape of the data rather than the code around it, this skill leads and hands back when the model is settled.

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap, not one each — pick the highest-impact issues across the whole set, and never restate a point a sibling already made.

`references/*.md` inside this skill are files to **read**, not skills to invoke — open the one the decision actually depends on.

## The objective: correct, cheap to change, cheap to run

A data model is judged on three things, and when they conflict, resolve in this order:

1. **Correct** — it cannot store or return wrong data. Integrity is the one property you can't trade, because wrong data is the only outcome you can't roll back.
2. **Cheap to change** — you will be wrong about the future, so make being wrong survivable. The model outlives the code that reads it.
3. **Cheap to run** — bytes stored, bytes read per query, and writes multiplied by every index and copy. This is a real invoice, and at scale it's the largest line item you control from a design document.

These agree far more often than people expect. A well-grained model with narrow keys, honest retention and indexes that match real access paths is usually *also* the cheapest to run, because duplication costs writes and storage while vague grain costs full scans. When they genuinely conflict — a read path that needs a denormalized copy — measure first, then buy the copy deliberately, with an owner and a rebuild path.

The expensive schema is not the one with an extra join. It's the one that produces wrong numbers, or the one nobody can change.

## The mindset, in six lines

- **A data model is a contract with people you'll never meet** — the next service, a backfill script, an analyst in two years. It's the one interface you can't deprecate quietly.
- **Wrong data is the only thing you can't roll back.** A bad deploy is reverted in five minutes; a month of silently wrong `total` values is a forensics project.
- **Constraints are cheap now and near-impossible later.** `NOT NULL` on an empty table is free; on 40M rows that already violate it, it's a cleanup project and a maintenance window.
- **Design for the questions, not the pages.** "Which customers churned after a price change?" is a question the model must answer. A dashboard is one query.
- **Storage is cheap; ambiguity is expensive.** Keeping a record you might need beats discovering the fact was never recorded.
- **Boring wins.** Typed fields, declared relationships, one fact in one place. Reach for the clever thing after a measurement says boring failed.

## How to operate

**Establish the context first — it changes every answer.** Which store and version, or which ORM. Greenfield, or an existing model with live data and traffic. How large the biggest datasets get and how fast they're written. Whether one service writes or many. Whether the data is tenant-scoped, regulated, or under retention rules. Guessing at these wastes the user's time; ask for the ones that matter to the decision at hand.

**When reviewing an existing model:** first pass is always to state the grain of each dataset out loud ("one record is exactly one ___"), classify each by kind (Part 2), and list the facts, crossing out anything that's a copy of another dataset's field. Then lead with what lets wrong data in or blocks future change — missing identity, undeclared relationships, everything nullable, a dataset with no clear owner — not stylistic nits. Cap at 5–7 issues unless asked for an exhaustive pass.

**When designing something new:** walk the recipe below out loud. Don't write a field before you can say what one record is.

**Output format** for each issue or principle:

```
### [Principle]

[One-sentence explanation]

**Bad:**
[the design that violates it]

**Good:**
[the design that follows it]

[Why the good version wins — 1-2 sentences.]
```

**Voice — speak like an architect, not a textbook.**

- **Never cite rule numbers or normal-form names in your output.** Say why concretely: "`customer_email` here is a copy of the customer record, so a customer changing their address leaves this row lying" — not "this violates 3NF." The numbering is internal scaffolding.
- **Never invent the user's schema.** Quote their actual datasets and fields. If inferring something unseen, say so and keep the invented part minimal.
- **Name the trade, don't hide it.** Most of these decisions cost something — normalizing costs joins, duplicating costs consistency, an index costs writes, splitting a store costs transactions. State what's being paid.
- **Match the user's energy.** "Should tags be their own collection?" gets two lines, not a tour of the altitudes.

---

## Part 1 — The three altitudes

Run these in order. Each answers a different question, and dropping down before the level above is settled is the single most common cause of a model nobody can fix later.

| Altitude | The question | You decide | You must NOT yet decide |
|---|---|---|---|
| **Conceptual** | What exists in this business, and how do things relate? | Entities, relationships, cardinality, vocabulary | Keys, types, datasets, anything about the store |
| **Logical** | What is a record, what identifies it, what must always be true? | Grain, identity, duplication policy, invariants, ownership | Field types, indexes, partitions, storage |
| **Physical** | How will this store serve it? | Types, indexes, partition/sort keys, layout, engine features | — |

**Conceptual** — say the business out loud in sentences. *"A customer places many orders. An order contains many products, each at the price agreed at the time of sale. An instructor teaches many sessions; a member books a seat in a session."* Nouns become candidate datasets, verbs become relationships, adjectives become fields. Use the user's own domain language — that vocabulary becomes the names, and a model that speaks the business's words needs far less documentation.

**Logical** — now fix identity and truth: what one record is, what makes it unique, which facts live where, which rules are inviolable, who may write it. Still no store in sight. A good logical model survives a change of database.

**Physical** — only now types, indexes, partitioning, and engine features, driven by the access paths you wrote down and the growth you expect.

**Bad:** "Let's add a JSON field and an index on it so it's flexible" — a physical decision standing in for an unmade logical one; nobody has said what the data *is*.

**Good:** decide what facts exist and which are queried; *then* the queried ones become typed fields with indexes, and only the genuinely open-ended tail stays a document.

This is also the honest answer to "how long will this take?" — conceptual is hours of conversation, logical is where the thinking is, physical is comparatively mechanical.

---

## Part 2 — Organising data: the six kinds

The most useful architectural move available to you: **before writing fields, say which kind of dataset this is.** The kind determines identity style, growth curve, whether records are ever updated, what indexes make sense, and what retention applies. Most modeling disasters are one kind being treated as another — usually an event log modeled as an entity and then updated in place.

| Kind | One record is | Identity | Growth | Mutable? | Index shape | Retention |
|---|---|---|---|---|---|---|
| **Reference** | a permitted value (currency, status) | natural code (`'USD'`) | tiny, bounded | rarely, by deploy or admin | primary key only | forever |
| **Entity** | a thing that exists (customer, product) | surrogate + natural unique | with the business | yes, in place | natural-key lookups + relationships | life of the business |
| **Relationship** | a link between entities (enrollment, tag) | the pair of parent keys | product of both sides | rarely — insert/delete | both directions | with its parents |
| **Event** | something that happened (payment, click) | surrogate + time | unbounded, append-only | **never** | `(subject, time)` | archive or roll up by age |
| **Derived** | a computed answer (daily totals, search doc) | mirrors its source | as its source | rebuilt wholesale | whatever the read needs | disposable |
| **Operational** | in-flight machinery (outbox, job, lock) | surrogate + state | high churn, roughly flat | constantly | partial, over unfinished records | delete when done |

How to use this:

- **Reference datasets buy you integrity for enumerations** — plus somewhere to hang a display label, a sort order and an `active` flag without a deploy. A declared reference to one beats a free-text field, and usually beats a native enum type (the engine map explains why enums resist change).
- **Entities are the only kind you routinely update in place.** If you're updating an event record, you've misclassified it.
- **Relationship datasets are where relationship *attributes* belong** — `enrolled_at`, `role`, `quantity`. Bolting these onto one of the entities is why teams can't answer "when did this become true?"
- **Event datasets are the backbone of history and analytics, and the main source of unbounded growth.** Append-only means safe to partition by time, cheap to archive, and immune to "who changed this?"
- **Derived datasets must never be the system of record.** If you can't rebuild it from the entities and events, it isn't derived — it's undocumented primary data.
- **Operational datasets have wildly different index needs**: usually a small partial index over the few unfinished records, not a general index over millions of completed ones.

**Bad:**
```sql
CREATE TABLE shipments (
  id int PRIMARY KEY,
  order_id int,
  status text,          -- overwritten on every transition
  updated_at timestamp
);
```
One dataset doing entity *and* event work. Ops asks "how long did it sit in customs?" and the answer was destroyed by the last update.

**Good:**
```sql
CREATE TABLE shipments (                 -- entity: what exists now
  id int PRIMARY KEY,
  order_id int NOT NULL REFERENCES orders(id),
  current_status text NOT NULL REFERENCES shipment_statuses(code)
);

CREATE TABLE shipment_status_events (    -- event: what happened, append-only
  id int PRIMARY KEY,
  shipment_id int NOT NULL REFERENCES shipments(id),
  status text NOT NULL REFERENCES shipment_statuses(code),
  occurred_at timestamp NOT NULL
);
```

The entity answers "where is it?" in one lookup; the event dataset answers every question about duration, ordering and blame. `current_status` is a derived convenience with a single owner — the code that appends the event.

This taxonomy is paradigm-independent. In a document store these are collections; in a wide-column store, partitions; in a warehouse, dimensions (reference/entity) and facts (event). The kinds don't change — only how you physically express them.

---

## Part 3 — The shape of one dataset

### 1. Fix the grain before the fields

Finish this sentence first: **"one record here is exactly one ___."** If you need "and" or "or", you have two datasets.

**Bad:** `user_dashboard(user_id, user_name, latest_order_total, unread_count)` — one record is one... user? order? both?

**Good:** `users`, `orders`, and the dashboard is a query or a derived projection.

Screens change every sprint; the fact that a user places orders doesn't. A dataset shaped like a screen must be rebuilt the first time the design changes, and can never answer a question the screen didn't ask.

- **Name it in the same breath, and spell the name out.** The noun that finishes the grain sentence *is* the dataset's name — if one record is one process definition, the dataset is `process_definitions`, never `proc_defs`. Naming is a logical decision made here, not a formatting pass applied later; the full standard is Principle 26.

### 2. One fact, one place — then decide duplication deliberately

If a value can be reached by following a relationship, don't copy it. Two stored copies of one truth will drift, and the database won't tell you which is right.

**Bad:** `orders(id, customer_id, customer_email, line_total_sum)` — the email goes stale the moment the customer edits it; the sum is maintained by hand in three code paths.

**Good:** resolve the email through the relationship; sum the lines at read time, or make the sum a derived dataset with one owner.

**The exception that isn't one — captured facts.** The price on an order line is *not* a copy of the product's price; it's a different fact: "what this customer agreed to, at that moment." The test: **if the source value changes, should this record change too?** Yes → it's a copy, resolve it. No → it's its own fact, store it. Getting this backwards is how repricing a product silently rewrites last year's revenue.

**Where the paradigm flips the default.** In a relational store, duplication is the exception you justify. In a document or wide-column store it is often the *design* — you duplicate to serve an access path because there are no joins. That doesn't repeal this principle, it relocates it: every duplicate needs a named owner and a rebuild path (Part 4). "Denormalized because the store demands it" is fine; "denormalized and nobody knows what fixes it when it drifts" is the same bug in both worlds. See `references/non-relational.md`.

### 3. Identity: surrogate key by default, natural key as a constraint

Every dataset needs a key that identifies the *thing*, not its position in a file.

- **Surrogate key** (a meaningless generated id) for anything other datasets reference: small, immutable, index-friendly, survives the business changing its mind.
- **Keep the natural key as a real unique constraint** alongside it. A surrogate key without it is how you get two records for one customer.
- **Never key on something mutable or personal** — email, phone, username. All change, and then every child record needs rewriting.
- **Composite natural keys are right for relationship datasets.** The pair *is* the identity.
- **Internal id ≠ public id.** The moment an id appears in a URL or API response it's a contract, and sequential ids leak volume and ordering. Consider a separate public token alongside the internal key.
- **Choose the key type deliberately — it is the least reversible decision here.** `bigint` identity by default; UUIDv4 is the wrong clustered/InnoDB primary key because random inserts scatter across the B-tree and split pages; UUIDv7 or ULID restores append locality when ids must exist before the write. UUIDv7 is RFC 9562, native as `uuidv7()` from Postgres 18 and app-side before that. In InnoDB the primary key is stored inside *every* secondary index record, so key width is multiplied across all of them whether or not they name it. The comparison table is in `references/engine-map.md`.

### 4. Model relationships explicitly

Each cardinality has one correct shape. Anything else discards integrity and can't be traversed or indexed properly.

- **1:N** — the reference lives on the *many* side. Never a list of ids on the one side.
- **M:N** — a relationship dataset keyed on the pair, indexed in both directions.
- **1:1** — share the identity. Worth it when the second half is optional, rarely read, or has a different access pattern; otherwise just add the fields.
- **Optional 1:1 vs nullable fields** — five nullable fields always all-set or all-null are a child dataset in disguise.
- **Self-reference** (manager, parent category) — a reference to the same dataset, plus a guard against self-parenting; deep trees may want a closure table or recursive queries.
- **Subtypes** (a payment that is card *or* bank) — either one dataset with a kind field and a constraint tying fields to it, or a parent with per-type children. Pick deliberately; don't leave it implicit.

**Bad:** `posts(id, tags text)` holding `'sql,design'` — renaming a tag means rewriting every record with a text match, and counting posts per tag is string surgery.

**Good:** `tags(id, slug)` plus `post_tags(post_id, tag_id)` keyed on the pair.

Relational mechanics for all of these are in `references/relational.md`; embed-vs-reference for document stores is in `references/non-relational.md`.

### 5. Make invalid records impossible

Anything expressible as a constraint should be one. The store is the only place a rule is enforced against *every* writer — this service, the next service, the backfill script, the human at 2am. Application-only validation is enforced only on the path that runs that code.

In rough order of how often they're missing: **not-null** (absence must be meaningful), **declared references** (orphan records are unfixable later), **uniqueness** (the invariant *and* the race guard — a unique constraint plus an upsert beats check-then-insert, which two concurrent requests will both pass), **value checks** (ranges, signs, mutual exclusion), and **overlap prevention** for bookings, subscriptions and shifts, which most teams implement as a buggy read-first and some engines enforce outright.

**When the store enforces little or nothing** — a schemaless document store, a key-value store — the rules don't disappear, they move. Put them in one schema-validation layer at the write boundary that every writer must pass through, and enable whatever native validation exists. The failure mode to avoid is rules living in three services' application code, each with a slightly different idea of what's valid.

Either way, write down the rules the store *can't* hold. That list is the specification for your validation layer, and it should be short.

### 6. Absence means "unknown" — don't overload it

Null is not zero, not empty, not false. It's absent knowledge, and it quietly poisons comparisons and aggregates. Every optional field should have one stated meaning.

**Bad:** `discount_pct numeric NULL` — no discount? unknown? not migrated yet? All three, forever.

**Good:** `discount_pct numeric NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100)`.

Default to required; make a field optional only when "we genuinely don't know" is a real state worth recording. Document stores add a second axis — a *missing* field differs from a field set to null — so pick one convention and enforce it at the write boundary. Relational null semantics, including how uniqueness treats nulls, are in `references/relational.md`.

### 7. Types are constraints — pick the narrowest true one

A field's type is the cheapest rule you'll write and the only one that can't be bypassed. The recurring offenders in every store: **floating point for money** (use integer minor units or exact decimal), **timestamps as strings or without a zone convention**, **strings for booleans, dates and enumerations**, **a length limit standing in for a real rule**, and **file bytes inline** instead of object storage with a key in the record. Exact type names per engine are in `references/engine-map.md`.

---

## Part 4 — Architecture across datasets

### 8. Every dataset has exactly one writer

The boundary that matters most, and the one most often left implicit. When two services write the same dataset, its schema is frozen by the slower team, every constraint becomes a negotiation, and nobody can reason about invariants.

**Bad:** billing and CRM both update `customers.status`, coordinating by convention.

**Good:** one service owns `customers` and publishes changes; the other keeps its own data and reacts. Ownership is per *dataset*, not per database.

Corollaries: the owner owns its migrations. A dataset read by others is a **published contract** — additive change only. One read by nobody else is private and free to churn. Knowing which is which is worth writing down.

### 9. What must be true together must live together

Your **consistency boundary** is the set of writes that must succeed or fail as one. It decides what belongs in a single store, and it's the real reason to split — or not split — a system.

If debiting one account and crediting another must be atomic, they belong in one store, full stop. If an order and its lines must appear together, same. Put them in separate stores and you've traded a transaction for a distributed protocol, and you now owe an outbox, idempotency, and a reconciliation job. That's a legitimate trade at scale — make it knowingly. This is also the sharpest constraint in stores with no multi-record transactions: there, the consistency boundary and the *record* boundary are the same thing, which is why document stores reward embedding what must change together.

**Bad:** splitting `orders` and `order_lines` across services because they're "different domains."

**Good:** the invariant "an order always has at least one line" keeps them together; a genuinely independent concern (search, analytics, notifications) gets its own store, fed from the source of truth.

### 10. One system of record; everything else derived and rebuildable

Caches, search indexes, warehouses, denormalized read models and materialized views are **projections**. For each, answer: what rebuilds this, and how long does that take? If you can't rebuild it, it isn't a projection — it's primary data with no backup.

The associated trap is **dual writes**: saving to the database and then to the search index diverges permanently the first time the second call fails, and nothing reconciles it. Feed projections from the source of truth — an outbox, change capture, or a scheduled rebuild — rather than writing to both.

### 11. Duplicate on evidence, with an owner and a rebuild path

One fact in one place is the default because it's the only shape where a fact can't disagree with itself. Duplicating is a performance trade made **after** a measurement.

Before adding any copy, answer three questions: *what read is slow, on production-sized data, with the plan in hand*; *who updates the copy on every write path*; *what rebuilds it when it drifts* — because it will. If the second answer is "several places," you've chosen a data-corruption bug. Options in increasing cost: an engine-maintained computed field, a materialized view or projection (rebuildable by definition), a trigger-maintained counter, and last, an application-maintained field with a documented reconciliation job.

### 12. Prefer appending history to overwriting it

An update destroys the previous value. If anyone will ever ask "what was it before?", "when did it change?", or "what did we charge in March?", the history has to be a record.

Three shapes: **created/updated timestamps on everything** (the free minimum — always), **an append-only event dataset** for the full trail of who changed what, and a **validity-range record** (`valid_from`, `valid_to`) when the question is "what was true on date X". The mirror-image mistake exists too: don't version a field nobody will ask about — that's just a slower dataset.

### 13. Scoping is structural, not conventional

When records belong to an owner — a tenant, a workspace, a region, a legal entity — that ownership is part of the record's identity. If it isn't in the key, the indexes, and the predicate, one forgotten filter is a cross-tenant data leak.

**Bad:** `contacts(id, email UNIQUE, ...)` — tenant B can't add a contact tenant A already has, and any query missing the tenant filter returns other people's records.

**Good:** the tenant field leads the key and the indexes, uniqueness is scoped per tenant, child datasets carry the tenant too so a traversal can't cross tenants, and the store enforces the filter (row-level security, or a mandatory scope in one data-access layer) rather than 200 call sites remembering.

In partitioned stores this principle and Part 5's partition key are the same decision: the scope *is* the partition.

### 14. Decide what a delete means, and what retention applies

Every declared reference implies a delete behaviour; choose it deliberately. **Cascade** for parts that can't exist alone, **restrict** for references that should block the delete, **set null** only where the child genuinely survives orphaned.

Then decide whether records are ever really removed. Soft delete is a real design decision with real costs: every uniqueness rule must be re-scoped to live records, every read needs the filter (put it in one view or one repository method, never every call site), and the records still occupy indexes. Take it when you need undo, audit, or legal retention — otherwise hard-delete and keep an audit trail. Note that "delete the user" in a privacy sense usually means *anonymize*, which is a modeling decision about which fields hold personal data.

Retention belongs in the design, not a later panic: per dataset, how long records stay hot, when they're archived or rolled up, and what deletes them. Event datasets especially — they're the ones that grow without bound. Some stores give you per-record TTL; prefer it to a hand-written cleanup job for *reclaiming space*. **It is not a correctness mechanism.** DynamoDB deletes expired items asynchronously, typically within a few days of expiry, and keeps returning them from `Query` and `Scan` until it does — so anything where expiry means "no longer valid" (sessions, tokens, carts, offers) must also filter on the expiry attribute at read time. Redis is the opposite: it evicts on access and never serves an expired key.

---

## Part 5 — Access paths, indexes and cost

### 15. Indexes are derived from a written access-path inventory

An index is not a decoration; it's a **physical answer to a specific question**. So write the questions down first. For each important read: the predicate, the sort, the expected selectivity, how often it runs. That short list is the design input — and it's usually the artifact nobody has.

**Bad:** one index per field, arrived at by intuition — `(status)`, `(created_at)`, `(customer_id)`, `(total)` — none matching the query the application runs.

**Good:** "recent open orders for a customer" gets one composite index on `(customer_id, status, created_at)`. One index, one access path, chosen because someone wrote the access path down.

An index you can't name a query for is a write tax you're paying for nothing.

**How binding this is depends on the paradigm, and this is the biggest difference between them.** In a relational store the access-path inventory is *advisory* — get it wrong and you add an index later, **online, using the engine's non-blocking build** (`CREATE INDEX CONCURRENTLY`, `ALGORITHM=INPLACE, LOCK=NONE`, `WITH (ONLINE=ON)` — but confirm the edition first: SQL Server's online index operations are Enterprise/Developer-only, and on Standard `WITH (ONLINE=ON)` fails with error 1712 instead of falling back, so the migration errors out rather than running offline); do it with the default blocking form on a large live table and "add it later" is an outage, not a correction. The lock and online-DDL table per engine is in `references/engine-map.md`. In a key-value or wide-column store the inventory is *the schema*: the partition and sort key determine what you can query at all, changing them means rewriting the dataset, and secondary indexes are limited and costly. So the further you sit from relational, the more the inventory must be right up front, and the more it dictates the model itself rather than decorating it.

### 16. Every index is a copy of your data, rented from the engine

That's the whole cost model. An index is a redundant, engine-maintained copy — so it costs storage, it costs write amplification on every write touching the covered fields, and it competes for cache. Same trade as duplication; the engine just keeps it consistent for you, which is why it's the *first* tool to reach for and a hand-maintained field is the last.

Practical consequences: **budget them** — an index per field on a write-heavy dataset is a self-inflicted throughput problem; **drop unused ones** (every engine can tell you which are never read); and remember an index on a growing event dataset grows forever.

### 17. Shape the index to the access path

The shapes worth knowing, in essentially every store:

- **Equality fields first, then ranges and sorts.** `(status, created_at)` serves "status = X order by created_at"; `(created_at, status)` doesn't serve equality on status. Field order is the single most common index mistake, and in wide-column stores it's the difference between a working query and an impossible one.
- **Index the child side of every relationship.** Without it, parent deletes and traversals scan.
- **A uniqueness rule is an invariant, not a performance tweak** — declare it as a constraint so intent is visible, and get the index as a by-product.
- **Covering** — adding the returned fields to the index (Postgres/SQL Server `INCLUDE (…)`, which stores them as payload rather than as search keys, so they don't bloat the key) lets a read be answered from the index. **Postgres caveat worth knowing before you promise the win:** visibility isn't stored in index entries, so an index-only scan still visits the heap for any page not marked all-visible in the visibility map — on a write-heavy table that's most pages and the gain is near zero. Check `Heap Fetches` in `EXPLAIN (ANALYZE)` before claiming it.
- **Partial / filtered** — index only the records you query (unfinished jobs, live records under soft delete). Enormous wins on operational datasets, and the standard answer to "unique among non-deleted." Support varies sharply by engine; check the engine map before promising it.
- **Expression** — if you query a transformation of a field, the index must be on that same expression or it won't be used.

Then confirm with the store's plan output on production-like volume, not fifty development records. **Reading the plan, fixing the query shape, and deciding which indexes should exist are all here** — `backend-best-practices` owns only the runtime wrapper around the query: parameterization, the transaction, the lock, the pool, the timeout.

### 18. Physical layout follows the growth curve

Once a dataset is large, *how it's laid out* matters as much as what's indexed. The design inputs are from Part 2: which kind it is, and how it grows.

**Partitioning** earns its keep when you can drop or archive whole partitions instead of deleting records — time-partitioned event datasets are the canonical case, turning a retention policy from an expensive delete into a cheap detach. It also helps when every read naturally carries the partition key (a tenant, a region). It does *not* help a dataset that's merely big but always fetched by primary key, and it costs planning complexity and some constraint flexibility.

**Choose the partition key so load spreads and reads stay local.** The two failure modes are opposites: a key too coarse (everything in one partition, or a monotonic timestamp so all writes land on the newest one) creates a hot spot; a key too fine forces reads to fan out across every partition. In partitioned stores this is the single highest-stakes physical decision — see `references/non-relational.md`.

**Hot/cold separation** is the same idea at another grain: recent records read constantly, old ones rarely. Keep the hot set small and its indexes small.

Order of operations: get the logical model right, index the real access paths, *then* consider partitioning. Partitioning a badly-grained dataset just gives you many badly-grained datasets.

### 19. Know what actually drives the bill

Three numbers, and every modeling decision moves at least one:

- **Bytes stored × copies.** The dataset, every index on it, every replica, and every retained backup. A five-column index on a billion-row table isn't one copy of five columns — it's one per replica and one in every backup you keep.
- **Bytes read per query.** In a warehouse this *is* the invoice — BigQuery's on-demand model bills by bytes processed, and pruned partitions aren't counted toward it. In a row store the same quantity shows up as cache hit rate. In DynamoDB it's capacity units, which scale with item size.
- **Writes × amplification.** One insert becomes one write to the dataset, plus one per affected index, plus one per projection you maintain by hand.

**In an MVCC engine, updates cost storage too.** Every Postgres `UPDATE` writes a new row version and leaves the old one for vacuum, so update-heavy designs pay in bloat and index churn, not just in write throughput. This changes two recommendations elsewhere in this skill: a **counter maintained by trigger or by the application is a bloat and lock hotspot** if it lives on a hot row — put it in its own narrow row, keep the counted column **unindexed** so the HOT-update optimization can apply (it is defeated the moment the updated column is indexed), and budget for autovacuum. And a high-churn operational dataset is an autovacuum-tuning problem, not a flat one: it needs aggressive per-table settings, not defaults. This is also why `COUNT(*)` is a scan — visibility lives in the heap, not the index.

Three levers move these more than anything else *at design time*, which is the only time some of them are available:

**Key width is multiplied.** The type you choose for a key is paid again in every index containing it and every child record referencing it. A 16-byte UUID instead of an 8-byte integer, across five indexes and three child datasets, is not a rounding error at 500M rows — and the real cost isn't disk, it's that fewer index pages fit in memory.

**Column order is occasionally free money in Postgres.** Fixed-width columns are padded out to alignment boundaries, so declaring them widest-first — 8-byte types, then 4, then 2, then 1-byte, with variable-length last — removes padding from every row. The win is real only on tables with many small fixed-width columns and is often near zero on a table of `text` and `timestamptz` with a 24-byte tuple header; measure with `pg_column_size` before caring. It costs nothing at creation time and there is no `ALTER` to reorder later, so take it as a tiebreaker when creating a table — never as a reason to churn an existing one. Doesn't apply to InnoDB's compact row format.

**Retention is the biggest long-run lever there is.** An event dataset with no retention policy grows forever, and so does every index on it and every backup of it. Rolling old records up, tiering them to cheap storage, or dropping whole partitions usually saves more than any query tuning you'll do that quarter.

---

## Part 6 — Writing efficient reads and writes

A model is only as cheap as the traffic run against it, and the two are the same design problem: a query is efficient when it uses the access path you designed and touches nothing else. **This skill owns the query outright** — projection, predicates, N+1 and round-trip count, paging, plan reading, batching, cost. `backend-best-practices` keeps only what wraps a query at runtime: parameter binding and injection, the transaction, the lock, the connection, the timeout.

### 20. Skip the read entirely where you can

The cost hierarchy starts above the query. An index makes a read cheaper; not doing the read makes it free — and it's the only lever that scales with *reader count* rather than with data size, which is why it beats query tuning on anything fronted by a popular screen.

**Bad:** every page load runs a twelve-table aggregate over all history, because the number it produces is "live".

**Good:** a derived dataset refreshed on a schedule, with the tolerated staleness written down next to it — and the page reads one row.

- **Precompute** when many readers ask the same question of slow-changing data. That's the same decision as duplicating on evidence (Part 4), so it inherits the same obligations: one owner, a rebuild path, and a known refresh cadence.
- **Cache** when the same answer is requested repeatedly and you can name a TTL you'd tolerate being stale for. Deciding *what* is worth caching is here; invalidation mechanics, stampede protection and cache-key hygiene are `backend-best-practices`.
- **Reuse within one request.** Three functions in one request each fetching the same row is N+1's quieter sibling — fetch once and pass it down.
- **Don't compute what nobody reads.** A dashboard aggregate rebuilt every minute and looked at twice a day is paying 720× for the privilege.

The precondition is honesty about freshness: **name the staleness you can tolerate before you build the copy.** If the answer is "none", you don't have a caching problem, you have a query to tune — carry on to the rest of this part.

### 21. Read the fewest bytes

The cheapest query is the one that reads least — not the one that returns least. Those differ, and the gap is where money goes.

**Bad:**
```sql
SELECT * FROM events WHERE user_id = $1 ORDER BY occurred_at DESC LIMIT 50;
```

**Good:**
```sql
SELECT id, kind, occurred_at
FROM events
WHERE user_id = $1
  AND occurred_at >= $2 AND occurred_at < $3
ORDER BY occurred_at DESC
LIMIT 50;
```

- **Project only the columns you need.** In a columnar store this is the single most expensive habit there is — `SELECT *` scans every column in the table, and selecting only what you need can cut bytes processed several-fold. **The row-store version of the same rule is TOAST:** in Postgres an oversized `text`/`jsonb`/`bytea` value is compressed and stored out-of-line, so a wide row is *not* automatically expensive to read — provided you don't select the toasted column. `SELECT *` on a table with a large `jsonb` column pays a de-TOAST cost that naming the other columns avoids entirely, and an `UPDATE` that doesn't touch the toasted column doesn't rewrite its chunks. The column list, not the row count, decides what you read.
- **`LIMIT` is not a cost control** in a warehouse: you're billed for bytes read, not bytes returned, so a limited query over an unpruned table costs the same as an unlimited one. (Clustered tables are the exception — scanning can stop early.) For exploration use the preview/head tooling, not `SELECT * … LIMIT 10`.
- **Filter on the partition or clustering key so pruning actually happens.** An unpruned scan is the most common surprise line on a warehouse bill; some engines let you *require* a partition filter so an unfiltered query errors instead of billing.
- **Aggregate at the source.** Pulling a million rows to the application to count them pays for the bytes, the network and the memory to do worse than the engine would.
- **Small queries aren't free either.** Warehouses bill a floor per referenced table per query (10 MiB in BigQuery), so thousands of tiny queries have a real cost — batch them.

### 22. Keep the predicate on the access path

An index only helps if the query is written so the engine can use it. The usual ways to accidentally opt out:

**Bad:** `WHERE date(created_at) = $1` — the column is wrapped in a function, so the index on `created_at` is unusable and you get a scan.

**Good:** `WHERE created_at >= $1 AND created_at < $1 + interval '1 day'` — a range predicate the index can serve.

- **Don't wrap the column** in a function or cast unless an index exists on exactly that expression.
- **Match the types.** Comparing an integer column to a string parameter, or joining columns of different types, forces a cast and drops the index.
- **A leading wildcard** (`LIKE '%term%'`) can't use a B-tree — that's a job for a trigram index (`pg_trgm` + GIN), full-text search, or a search engine.
- **`OR` across different columns** can't be served by one composite index. The **first** fix is a separate index per branch, which Postgres combines with a bitmap OR and MySQL sometimes handles with `index_merge` — no query rewrite needed. Only if the plan still scans, rewrite as two indexed queries combined with `UNION` (note it de-duplicates and sorts; use `UNION ALL` when the branches are disjoint).
- **In a partitioned store, a query without the partition key fans out to every partition.** That isn't a slow query, it's a distributed full scan, and it's the same mistake as an unpruned warehouse scan.

### 23. Bound it, and do it in one round trip

**Bad:**
```python
for order in orders:                                   # N+1: one query per row
    lines = db.query("SELECT * FROM order_lines WHERE order_id = ?", order.id)
```

**Good:**
```python
lines = db.query("SELECT order_id, sku, qty FROM order_lines WHERE order_id = ANY(?)",
                 [o.id for o in orders])               # one round trip, grouped in memory
```

- **Every read gets a bound.** An unbounded result set is a latency and memory incident waiting for the row count to grow.
- **Paginate by keyset, not `OFFSET`.** `OFFSET 100000` reads and discards a hundred thousand rows; `WHERE (created_at, id) < ($1, $2) ORDER BY … LIMIT n` reads only the page.
- **`COUNT(*)` on a large dataset is a scan.** Fetch `limit + 1` and report "has more", keep a maintained counter, or accept an approximate count.
- **Kill N+1** — a query per element is the most common real performance bug in production code, and the fix is always one batched round trip.
- **A fan-out join patched with `DISTINCT`** is an expensive sort hiding a modeling bug. When you reach for `DISTINCT`, check the grain of what you joined (Part 3) before optimizing the query.

Then confirm with the engine's plan on production-like data. A prediction about a plan is a hypothesis; the plan is the evidence.

### 24. Write in batches, not one row at a time

The write path has its own N+1, and it's the one people leave in production because each individual write looks fast.

**Bad:**
```python
for row in rows:                                    # one round trip and one transaction per row
    db.execute("INSERT INTO events (user_id, kind, occurred_at) VALUES (?, ?, ?)", row)
```

**Good:**
```python
db.copy_from(rows, "events", columns=("user_id", "kind", "occurred_at"))   # one bulk load
# or, without a bulk API: one multi-row INSERT per few-thousand-row chunk, one commit per chunk
```

- **Per-row round trips pay network latency and per-statement overhead once per row**, and the gap against a batched path is routinely one to two orders of magnitude. Use the engine's bulk loader when the volume is real (`COPY`, `LOAD DATA`, bulk-insert APIs, batch write operations) and a chunked multi-row `INSERT` otherwise.
- **Batch large `UPDATE`/`DELETE` by key range, with a commit per batch.** One giant statement holds locks for its whole duration, bloats an MVCC table, and lags replicas — the batched version is slower in total and far cheaper in impact. (The lock and transaction semantics of doing so are `backend-best-practices`.)
- **In columnar and append-optimized stores, row-at-a-time insert is pathological**, not merely slow: each write becomes a part or file the engine must later merge, so you pay again in background compaction. Buffer and write in large batches.
- **Remember writes are multiplied** (Part 5): every index and hand-maintained projection is another write. For a genuinely large load, dropping non-essential indexes and rebuilding them afterwards can beat maintaining them row by row — when you can afford the window.
- **Bound the batch.** An unbounded batch is a memory spike and a long lock hold. Size it deliberately, don't maximize it.

---

## Part 7 — Designing for change

### 25. Assume every change happens under live traffic

Everything you create will be altered while the old code is still running and data is still being written. Prefer shapes cheap to evolve over shapes elegant today.

The habits that pay: **names are a contract** — spend the extra minute now, because renaming later is a multi-deploy project; **never repurpose an existing field's meaning** (add a new one and retire the old — a field whose meaning changed on a Tuesday is unanalyzable forever); **additive beats destructive**; **one logical change per migration**; and prefer designs that grow by adding *records to a child dataset* over designs that grow by adding *fields*.

**In schemaless stores this discipline matters more, not less.** "No migration needed" really means "every version of every record is still in there, and your readers must cope." Version your documents, write tolerant readers that handle missing and extra fields, and decide whether you migrate lazily on read or with a backfill — but decide, rather than discovering five shapes in production. The mechanics of running migrations safely, and which operations lock, are `backend-best-practices` and the engine map.

### 26. The model is the documentation

A model with declared identity, relationships and constraints answers "what is legal here?" without a wiki, and can't go stale the way a document does. The diagram generates itself, tooling reflects it correctly, tests get a free oracle, and every constraint violation is a bug caught at write time instead of a wrong number in a report six weeks later. Where the store won't hold the constraints, the schema-validation layer from Part 3 is the documentation, and it deserves the same care.

**Which is why the names carry most of the documentation, and why you spend them like a budget.** A name is read thousands of times — by an analyst in a query console, a BI tool's field picker, an incident channel at 2am — none of whom have your diagram open. An invented abbreviation saves the author four keystrokes once and charges every reader a guess forever. And unlike a comment, a bad name doesn't just sit there: it propagates into every view, export, report and dashboard built on top, so renaming it later is a migration *plus* an archaeology project.

**Bad:**
```sql
CREATE TABLE proc_defs (
  id int PRIMARY KEY, seq_no int, sla_hrs int, cur_ver_id int, dt_crt timestamp
);
CREATE TABLE proc_def_deps (def_id int, dep_id int);
```

**Good:**
```sql
CREATE TABLE processes (
  id bigint PRIMARY KEY, sequence_number smallint, sla_hours int,
  current_version_id bigint, created_at timestamptz
);
CREATE TABLE process_dependencies (process_id bigint, depends_on_process_id bigint);
```

`defs`, `deps`, `seq`, `hrs`, `cur`, `ver` and `dt_crt` are words the author invented. `sla_hours` survives the rewrite because SLA is the *business's* word, not the author's — that's the whole distinction.

- **Spell it out. No invented abbreviations, ever.** `definitions` not `defs`, `dependencies` not `deps`, `number` not `no`/`num`, `quantity` not `qty`, `amount` not `amt`, `description` not `desc` (also a reserved word), `sequence` not `seq`, `version` not `ver`, `latitude`/`longitude` not `lat`/`lng`, `deduplication` not `dedupe`, `attempt_count` not `attempts`. The test: **would you say the word out loud in a meeting?** If not, it isn't a name.
- **Keep the domain's abbreviations; never mint your own.** `sla_hours`, `kyc_status`, `gst_number`, `iban`, `sku`, `vat_rate`, `utm_source` are the business's vocabulary, and expanding them makes the model *less* legible to the people who use it. `cust_ref_no` is not vocabulary. The line is whether a domain expert already says it aloud — use the business's words (recipe step 1), not your own shorthand.
- **Distinguish the template from the instance in the name, not with a suffix.** The configuration dataset takes the plain noun; the instance dataset takes its owner as a prefix. `steps` is the definition and `subject_steps` is one subject walking through it — which reads better than `step_defs`/`step_instances` and makes the grain legible from the name alone. Same for `forms` versus `form_submissions`.
- **Suffixes are a contract: choose once, never vary.** `_id` for a reference, `_at` for a timestamp, `_on` for a date, `_count` for a tally, `_number` for a human-facing sequence, `_minor` for integer money units, `is_`/`has_` for booleans. A reader who learns one dataset can then predict every other, and tooling stops needing per-column overrides.
- **Plural dataset, singular field, and the field never repeats the dataset.** `users.email`, never `users.user_email`, never `tbl_user.usr_email_str`. No type in the name and no Hungarian prefix — the type is already declared, and it will change before the name does.
- **A name that needs a comment is the wrong name.** Reaching for a column description to explain what a column *is* means renaming it instead. That's always the cheaper fix and the only one that reaches the person querying it in two years. (Descriptions are still worth writing for grain and provenance — just not to translate your abbreviation.)
- **Names are the least reversible decision in this skill.** A rename is expand-migrate-contract under live traffic (Principle 25) against every dependent view, integration and dashboard. Ten minutes of naming now beats a quarter of aliasing later.

---

## Paradigm map

Same principles, different physics. Read across the row to see what changes.

| Concern | Relational | Document | Key-value / wide-column | Search | Columnar / warehouse |
|---|---|---|---|---|---|
| Unit | row in a table | document in a collection | item in a partition | indexed document | row in a wide table |
| Relationships | declared reference, joins | embed or reference, no joins | duplicate into the access path | flattened at index time | star: facts + dimensions |
| Access paths | advisory — add an index later | mostly advisory | **binding** — the key *is* the schema | query-driven analyzers | scan-oriented, clustering keys |
| Integrity | engine-enforced | native validation, often optional | almost none — your write layer | none | none — enforced upstream |
| Duplication | the exception you justify | often the design | the design | always (it's a projection) | dimensional, versioned |
| Transaction scope | multi-row, ACID | usually per document | usually per item/partition | none | batch load |
| Source of truth? | yes | yes | yes | **never** | **never** |
| Schema change | migration under traffic | tolerant readers + versioning | rewrite the dataset | reindex | recompute the table |

Two rules read straight off this table: **never let a search index or a warehouse be your system of record**, and **the further right you sit, the more the access-path inventory must be correct before you write anything.**

---

## The recipe for any new model

1. **Write the domain in sentences**, in the business's own words. Nouns → candidate datasets, verbs → relationships, adjectives → fields. *(Conceptual)*
2. **Write the questions the data must answer**, and how often each is asked. This is your access-path inventory; you'll use it in step 8, and it exposes entities you forgot.
3. **Classify each dataset** — reference, entity, relationship, event, derived, operational. *(Part 2)*
4. **Fix the grain, then name it**: "one record is exactly one ___," in one sentence, each — and name the dataset that noun, spelled out in full. *(Principle 26)*
5. **Choose identity** — surrogate key plus the natural key as a constraint.
6. **Place each fact once.** Then check every apparent duplicate against the captured-fact test, and give any deliberate copy an owner and a rebuild path.
7. **Turn every business rule you can into a constraint**, and write down the ones the store can't hold — that list is your validation layer.
8. **Draw the boundaries**: who writes each dataset, what must commit together, what is a published contract, what is a projection and how it rebuilds.
9. **Only now go physical**: types (narrowest true type, and widest-first where alignment costs you), then indexes from step 2, then partition key and layout from the growth curve.
10. **Price the top access paths.** For each of the few queries that run constantly: does it read a bounded index range or scan? Does it prune partitions? What does one insert cost in index writes? If you can't answer, you don't yet know what this design costs to run.
11. **Ask the four future questions**: what history is needed, what a delete means and how long records live, what scoping applies, and what the next schema change will be.

Steps 1–8 are store-independent and portable. Steps 9–10 are where you open the engine map.

---

## The whole thing on one card

| # | Principle | One line |
|---|---|---|
| — | Altitudes | Conceptual, then logical, then physical. Never skip upward. |
| — | Six kinds | Reference, entity, relationship, event, derived, operational — each with its own identity, growth and indexing. |
| 1 | Grain first | "One record is exactly one ___," before any field. |
| 2 | One fact, one place | Don't copy what you can resolve — unless it's a captured fact, or the store gives you no joins and you own the copy. |
| 3 | Identity | Surrogate key by default, natural key as a constraint, never key on mutable data. |
| 4 | Relationships explicit | Reference on the many side; a keyed dataset for many-to-many; never a delimited list. |
| 5 | Invalid records impossible | If it can be a constraint, make it one; where the store won't, one validation layer at the write boundary. |
| 6 | Absence means unknown | Default to required; give every optional field one stated meaning. |
| 7 | Types are constraints | Narrowest true type. No float money, no stringly-typed anything. |
| 8 | One writer per dataset | Ownership is per dataset; anything others read is a published contract. |
| 9 | Consistency boundary | What must be true together must live together — splitting costs you a transaction. |
| 10 | One system of record | Everything else is a projection with a known rebuild path. No dual writes. |
| 11 | Duplicate on evidence | A measurement, a named owner, and a rebuild path — or don't. |
| 12 | Append history | If anyone will ask "what was it before?", update is the wrong verb. |
| 13 | Scoping is structural | Tenant/owner in the key and the index, enforced by the store. |
| 14 | Deletes and retention | Choose each delete behaviour; decide up front what ages out and how. |
| 15 | Access paths first | Write the queries down; indexes answer them — and in partitioned stores they *are* the schema. |
| 16 | Indexes are rented copies | Every one taxes writes — budget them, drop the unused. |
| 17 | Shape the index | Equality then range; index the child side; partial for operational datasets. |
| 18 | Layout follows growth | Partition to drop and archive whole ranges; pick the key so load spreads and reads stay local. |
| 19 | Know the bill | Bytes stored × copies, bytes read per query, writes × amplification. Key width and column order are paid everywhere; retention is the biggest lever. |
| 20 | Skip the read you can avoid | Precompute, cache or reuse within a request — but name the staleness you'll tolerate first. |
| 21 | Read the fewest bytes | Project only what you need; `LIMIT` is not a cost control; filter so partitions prune; aggregate at the source. |
| 22 | Predicate on the access path | Don't wrap the column, match the types, never fan out across every partition. |
| 23 | Bound it, one round trip | Keyset not `OFFSET`; no `COUNT(*)` on big data; kill N+1; `DISTINCT` usually hides a grain bug. |
| 24 | Batch the writes | Bulk load over row-at-a-time; batch big `UPDATE`/`DELETE` by key range; bound the batch. |
| 25 | Change is constant | Additive over destructive; names are contracts; never repurpose meaning. |
| 26 | The model is documentation | Constraints explain the domain and never go stale — and the names carry it. Spell every name out; no invented abbreviations. |

If you forget all of it: **say what one record is, decide which kind of dataset it is and who owns it, place every fact exactly once, turn the business rules into constraints, and let the access paths decide the indexes, the reads and the writes.** Logical model first, physical second, duplication only with a measurement and an owner. Skip the read you don't need, batch the write you do. Correct beats cheap, and the cheapest model is usually the correct one anyway.

## References

- `references/relational.md` — relational mechanics: normalization in plain words, reference/junction shapes, null and uniqueness semantics, the constraint catalog including overlap prevention, soft-delete uniqueness, tenant scoping and row-level security.
- `references/non-relational.md` — document, key-value/wide-column, search and warehouse modeling: embed vs reference, unbounded arrays, partition and sort key design, hot partitions, single-table design, secondary-index costs, projections and eventual consistency.
- `references/engine-map.md` — concept-by-concept syntax across Postgres, MySQL, SQLite, SQL Server and Oracle: identity and sortable keys, timestamp and money types, closed value sets, document columns, partial indexes, upserts, overlap constraints, and which lock a given change takes.

Read the relevant one when a decision depends on the store's actual capability, rather than recalling a version number.
