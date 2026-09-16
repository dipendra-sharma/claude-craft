# Engine map

Concept-by-concept translation for the physical altitude. Read the row you need; don't recall a version number.

Version-sensitive rows name the version that introduced the feature. **Anything that gates a migration — a lock level, an online-DDL algorithm, a preview-vs-GA status — gets re-checked against the vendor doc for the version actually deployed before you run it.** Treat this file as a map, not as a warrant.

## Core types and features

| Concept | Postgres | MySQL 8 | SQLite | SQL Server | Oracle |
|---|---|---|---|---|---|
| Surrogate key | `bigint GENERATED ALWAYS AS IDENTITY` | `BIGINT AUTO_INCREMENT` | `INTEGER PRIMARY KEY` (rowid alias) | `BIGINT IDENTITY(1,1)` | `GENERATED AS IDENTITY` (12c+) |
| Sortable UUID | `uuid` + `uuidv7()` (PG18+), else app-side | `BINARY(16)` + `UUID_TO_BIN(UUID(),1)` | `BLOB`/`TEXT` | `uniqueidentifier` + `NEWSEQUENTIALID()` | `RAW(16)` |
| Instant in time | `timestamptz` | `TIMESTAMP` (UTC, range ends 2038) or UTC `DATETIME` | `TEXT` ISO-8601 / `INTEGER` epoch | `datetimeoffset` | `TIMESTAMP WITH TIME ZONE` |
| Money | `numeric(19,4)` or `bigint` minor units | `DECIMAL(19,4)` | `INTEGER` minor units | `decimal(19,4)` | `NUMBER(19,4)` |
| Closed value set | `text` + `CHECK`, or reference table | same (avoid native `ENUM`) | `TEXT` + `CHECK` | `nvarchar` + `CHECK` | `VARCHAR2` + `CHECK` |
| Document field | `jsonb` + GIN | `JSON` + indexed generated column | JSON funcs (built in from 3.38), `JSONB` (3.45+) | `json` (Azure SQL; SQL Server 2025+) else `nvarchar(max)` + `ISJSON` | `JSON` (21c+) / `CLOB` + `IS JSON` |
| Partial / filtered index | `CREATE INDEX … WHERE …` | **not supported** | `CREATE INDEX … WHERE …` (3.8+) | filtered index | function-based index returning NULL for excluded rows |
| Computed field | generated column — `VIRTUAL` (PG18+, the default there) or `STORED` (the only kind before 18; needed to index it) | `VIRTUAL` or `STORED` generated | generated column | computed column | virtual column |
| Upsert | `INSERT … ON CONFLICT DO UPDATE` | `INSERT … ON DUPLICATE KEY UPDATE` | `ON CONFLICT DO UPDATE` (3.24+) | `MERGE` — read its caveats | `MERGE` |
| Overlap prevention | `EXCLUDE USING gist` | trigger / app lock | trigger | trigger | trigger |
| Unique treats nulls as equal | `UNIQUE NULLS NOT DISTINCT` (PG15+) | no — multiple nulls allowed | no | no | no |
| Row-level security | `ENABLE ROW LEVEL SECURITY` + policy | no native RLS | no | security policies | VPD / RAS |

## Notes that bite

**Native enums resist change.** Postgres has no way to drop a value from an enum type. Before PG12, `ALTER TYPE … ADD VALUE` couldn't run inside a transaction block unless it was part of the same transaction that created the type; from PG12 it can run in any transaction, but the new value can't be used until that transaction commits. MySQL enums reject an invalid value only under strict mode (the 8.0 default); with it off they silently store `''` (index 0) with a warning, and reordering or removing values rebuilds the table. Prefer `text` + `CHECK` for a small fixed set, or a reference table when the set has attributes or changes without a deploy.

**MySQL has no partial indexes**, and this is the one gap that most often changes a design. For "unique among non-deleted rows," add a generated column that is `NULL` for deleted rows and a unique index on it — a MySQL unique index permits multiple nulls, so deleted rows stop colliding:

```sql
ALTER TABLE users
  ADD COLUMN email_live varchar(255)
    GENERATED ALWAYS AS (IF(deleted_at IS NULL, email, NULL)) VIRTUAL,
  ALGORITHM=INSTANT;

ALTER TABLE users
  ADD UNIQUE KEY uk_users_email_live (email_live),
  ALGORITHM=INPLACE, LOCK=NONE;
```

**Two statements, never combined, and always state `ALGORITHM=` explicitly.** Adding a virtual column and adding a key in one `ALTER` fails under `ALGORITHM=INPLACE` with error 1846 — *"INPLACE ADD or DROP of virtual columns cannot be combined with other ALTER TABLE actions"* — and if you omit the clause MySQL does not error, it silently falls back to `ALGORITHM=COPY` and rebuilds the entire table. On a large `users` table that is a multi-hour rebuild nobody asked for. Naming the algorithm converts a silent outage into a loud error you can fix.

Use `VIRTUAL`, not `STORED`: a stored generated column forces a full table copy.

**MySQL enforces `CHECK` only from 8.0.16.** Earlier versions parse and ignore it, which is worse than not having it.

**Postgres exclusion constraints need `btree_gist`** for equality on a scalar column:

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE subscriptions ADD CONSTRAINT one_open_per_account
  EXCLUDE USING gist (account_id WITH =, tstzrange(started_at, ended_at) WITH &&);
```

`tstzrange(x, NULL)` is unbounded above, so two open-ended rows for the same account necessarily overlap and the second is rejected — which is exactly the "only one active subscription" rule.

**`SET NOT NULL` on a large Postgres table** scans it under an `ACCESS EXCLUSIVE` lock. Add `CHECK (col IS NOT NULL)` as `NOT VALID`, then `VALIDATE CONSTRAINT` (which takes only `SHARE UPDATE EXCLUSIVE`); from PG12 that validated constraint lets `SET NOT NULL` skip its own scan.

**`ADD COLUMN … DEFAULT` is fast from PG11** for any non-volatile default — no table rewrite. A volatile default, a stored generated column, an identity column, or a constrained domain type still forces one.

**`REFRESH MATERIALIZED VIEW CONCURRENTLY` requires a unique index** on the view. Without one you get the blocking form.

**`RESTRICT` vs `NO ACTION` (Postgres)** differ only in deferrability: `NO ACTION` allows the check to be deferred to end of transaction, `RESTRICT` does not. In MySQL the two are synonyms.

**`text` vs `varchar(n)` in Postgres**: no meaningful performance difference beyond a few CPU cycles to check the length; the real differences are the limit itself and that over-length input errors rather than being accepted. (`char(n)` blank-pads and is usually slowest — avoid.) A length limit is a storage guess, not a business rule; prefer `text` plus a `CHECK` stating the actual rule.

**`UUID_TO_BIN(uuid, 1)`** swaps the time-low and time-high bytes to improve index locality, and returns `VARBINARY(16)` for storage in a `BINARY(16)` column. The swap only helps because MySQL's `UUID()` emits time-based version-1 UUIDs — it's pointless on a random UUID.

**SQL Server `MERGE`** has documented correctness and concurrency issues at scale; many practitioners use an explicit `UPDATE` then `INSERT` inside a transaction with `HOLDLOCK` instead.

**Oracle's "partial indexes"** (12c) are a different feature — they apply only to partitioned tables via `INDEXING ON/OFF`. For a Postgres-style partial index on an ordinary table, use a function-based index whose expression returns `NULL` for excluded rows, since **Oracle** B-tree indexes don't store all-null keys. (This is an Oracle property, not a general one — Postgres B-trees *do* index nulls, which is why partial indexes on `IS NULL` work there.)

## Choosing the primary key

The least reversible decision in a schema, and the one most often made by habit.

| Choice | Width | Locality | Use when |
|---|---|---|---|
| `bigint` identity | 8 B | perfect (append) | Default. Leaks row volume and creation order if exposed publicly. |
| UUIDv4 | 16 B | none — scatters | Almost never as a clustered/InnoDB PK; random inserts cause page splits and cache misses. |
| UUIDv7 / ULID | 16 B | good (time-prefixed) | Ids generated client-side, merged across shards, or needed before the insert. |

- **UUIDv7 is standardised in RFC 9562** (May 2024, which obsoletes RFC 4122). Postgres has a native `uuidv7()` **from PG18**; before that, generate app-side. MySQL has no native v7 generator.
- **InnoDB multiplies PK width across every index by construction** — each secondary-index record carries the primary-key columns, whether or not the index names them. A 16-byte PK is therefore paid again in every index on the table. MySQL's own guidance: it is advantageous to have a short primary key. Postgres heap indexes store only the indexed columns plus a 6-byte `ctid`, so the multiplication doesn't apply the same way.
- **Default recommendation:** `bigint` identity PK, plus a separate indexed public token (UUID/ULID/nanoid) when ids are exposed. Reach for UUIDv7 as the PK when ids must be generated before the write reaches the database.

## Index types — pick the structure, not just the columns

Postgres names, but the shapes generalise.

| Type | Answers | Notes |
|---|---|---|
| **B-tree** | equality, range, sort, unique | The default, and right almost always. |
| **Hash** | equality only | No range, no sort, no unique. Rarely worth choosing. |
| **GIN** | multi-valued containment — `jsonb`, arrays, full-text, trigram | The answer for `@>` on `jsonb` and for `pg_trgm` on `LIKE '%term%'`. Slower to update. |
| **GiST** | ranges, geometry, nearest-neighbour, exclusion constraints | What `EXCLUDE USING gist` needs; add `btree_gist` for scalar equality. |
| **BRIN** | huge tables whose column correlates with physical order | Tiny (fractions of a percent of a B-tree) and the right choice for a timestamp on a large append-only event table. No unique, wide ranges, useless once the correlation breaks. |

The most common miss is putting a B-tree on `occurred_at` over a billion-row append-only table where BRIN would cost a thousandth of the storage and write amplification.

## Locks and online DDL — what a change actually costs

Before running any of these on a live table, check the row for the engine you're on. This is the difference between "add an index later" being cheap and being an outage.

| Change | Postgres | MySQL 8 (InnoDB) | SQL Server |
|---|---|---|---|
| Add index | `CREATE INDEX CONCURRENTLY` (no write lock; two scans; can't run in a transaction; leaves `INVALID` on failure) | `ALGORITHM=INPLACE, LOCK=NONE` | `WITH (ONLINE=ON)` (Enterprise) |
| Drop index | `DROP INDEX CONCURRENTLY` | in-place, no rebuild | online |
| Add nullable column, no default | instant | `ALGORITHM=INSTANT` (8.0.12+) | instant |
| Add column with default | instant from PG11 for non-volatile defaults; volatile default, stored generated, identity or constrained domain still rewrites | `INSTANT` (8.0.12+) for most; check | instant for nullable; `NOT NULL` with a runtime-constant default is metadata-only on Enterprise (2012+) but rewrites on Standard and for `(max)`/`xml` columns |
| `SET NOT NULL` | scans under `ACCESS EXCLUSIVE` — use `CHECK … NOT VALID` → `VALIDATE` → then it skips the scan (PG12+) | rebuild | rebuild |
| Change column type | usually full rewrite | usually `COPY` | usually rewrite |
| Add FK | `NOT VALID` then `VALIDATE CONSTRAINT` to avoid the long lock | `INPLACE`, `LOCK=NONE` | `WITH NOCHECK` then check |
| Add unique constraint | build the index `CONCURRENTLY`, then `ADD CONSTRAINT … USING INDEX` | `INPLACE` | online index then constraint |
| Add virtual/generated column | `STORED` rewrites; `VIRTUAL` (PG18+, the default there) never does — computed on read, no storage, can't be indexed | `INSTANT` — but **never combined with another action** (error 1846, see above) | non-persisted computed column is metadata-only; `PERSISTED` writes every row |

Two rules that hold everywhere: **set `lock_timeout` (and `statement_timeout`) in every migration** so a blocked DDL fails instead of queueing all traffic behind it, and **one DDL change per migration** — Postgres DDL is transactional, MySQL's is not, so a failed multi-statement MySQL migration leaves the schema half-applied.
