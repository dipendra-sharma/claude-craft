# Relational mechanics

The parts of the discipline that are specific to SQL databases. The parent skill owns the reasoning; this owns the machinery. Syntax per engine is in `engine-map.md`.

## Normalization, in plain words

You don't need the numbered forms to get this right. The working test is one sentence: **every column depends on the key, the whole key, and nothing but the key.**

- *Depends on the key* — if a column isn't about the thing the key identifies, it belongs elsewhere. `orders.customer_email` depends on the customer, not the order.
- *The whole key* — with a composite key, a column that depends on only half of it belongs in the table keyed by that half. On `order_lines(order_id, sku)`, a `product_name` depends only on `sku` → it belongs on `products`.
- *Nothing but the key* — a column that depends on another non-key column belongs with it. `subtotal`, `tax` and `total` on `invoices`: total is a function of the other two, so storing all three lets the arithmetic disagree with itself. Derive it, or make it a generated column the engine maintains. (Addresses look like this and are **not** — a captured address is its own fact, not a lookup; see below.)

Also worth internalising: **repeating groups are a table.** `phone1, phone2, phone3` and `tag1, tag2, tag3` are child tables written sideways. The moment you need a fourth, you're altering a schema instead of inserting a row.

Two well-known exceptions to the default, both requiring an owner and a rebuild path:

1. **Captured facts** — the agreed price on an order line, the address a parcel actually shipped to. Not copies; separate facts that must not change when the source does.
2. **Measured denormalization** — a counter or rolled-up total, added after a plan showed the join was the bottleneck.

## Two shapes that throw the model away

**EAV — entity/attribute/value.** A table of `entity_id, attribute_name, attribute_value text`, usually sold as "flexible settings" or "custom fields":

```sql
CREATE TABLE user_settings (user_id int, key varchar(100), value text);
```

It buys flexibility by discarding everything a database is for. There are no types — every value is text. There are no per-attribute rules: you cannot say that `theme` must be one of three values, or that `max_seats` is a positive integer. Nothing can reference a value. And no index is much use, because a read that wants three attributes becomes a three-way self-join pivot, written again in every report.

The distinction that resolves it: if the attribute set is defined by *your product*, it isn't flexible data — those are columns you haven't written yet. Use typed columns, plus one document field for a genuinely sparse tail. If the set is truly defined by each *customer*, then the attribute has an identity and deserves a definition table (`custom_fields`, with a type and validation rules) and a value table keyed by it — so the flexibility is modeled instead of abandoned.

**JSON as the primary model.** Everything in one `json`/`jsonb` column, queried with path operators. The losses are the same as EAV: no `NOT NULL`, no foreign keys, no uniqueness, and a B-tree can't help unless you add an expression or GIN index. Promote a field to a real column the first time you filter, join, sort or constrain on it, and keep JSON for sparse, append-only, or caller-shaped extras. "We'll figure out the schema later" usually turns into "we discovered our data was never valid."

## Relationship shapes

**One-to-many** — the foreign key goes on the many side, and gets an index:

```sql
CREATE TABLE orders (
  id int PRIMARY KEY,
  customer_id int NOT NULL REFERENCES customers(id)
);
CREATE INDEX ON orders (customer_id);
```

**Many-to-many** — a junction table keyed on the pair, indexed both ways. Relationship attributes live here:

```sql
CREATE TABLE enrollments (
  student_id int NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  course_id  int NOT NULL REFERENCES courses(id)  ON DELETE RESTRICT,
  enrolled_at timestamp NOT NULL,
  role text NOT NULL REFERENCES enrollment_roles(code),
  PRIMARY KEY (student_id, course_id)
);
CREATE INDEX ON enrollments (course_id);
```

The primary key on the pair *is* the "can't enroll twice" rule — you get the invariant and the forward index in one declaration. The second index serves the reverse lookup ("who is in this course?"), which the composite key alone can't.

**One-to-one** — share the primary key, so the constraint is structural:

```sql
CREATE TABLE user_profiles (
  user_id int PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  bio text NOT NULL DEFAULT ''
);
```

**Subtypes** — one table with a discriminator and a constraint tying the fields to it:

```sql
CREATE TABLE payment_methods (
  id int PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN ('card','bank')),
  card_last4 text,
  bank_account_id int REFERENCES bank_accounts(id),
  CONSTRAINT fields_match_kind CHECK (
    (kind = 'card' AND card_last4 IS NOT NULL AND bank_account_id IS NULL) OR
    (kind = 'bank' AND bank_account_id IS NOT NULL AND card_last4 IS NULL)
  )
);
```

Use the single-table form when the types share most fields and are queried together; use a parent plus per-type child tables when they diverge sharply or each has many of its own columns.

## Null semantics — the traps

- **`x = NULL` is never true.** Use `IS NULL`. Comparisons against null yield unknown, not false.
- **`NOT IN` with a null returns nothing.** `WHERE id NOT IN (SELECT parent_id FROM t)` silently returns zero rows if any `parent_id` is null. Use `NOT EXISTS`.
- **Aggregates skip nulls.** `COUNT(col)` ignores them while `COUNT(*)` doesn't; `AVG` divides by the non-null count.
- **Uniqueness normally ignores nulls.** `UNIQUE(email)` permits unlimited rows with a null email. If that's wrong, make the column `NOT NULL`, or use `UNIQUE NULLS NOT DISTINCT` where supported.
- **Concatenation and arithmetic propagate null.** One null field makes the whole expression null unless you coalesce.

The cheapest defence is `NOT NULL` with a sensible default on everything except fields where "we don't know" is a real, recorded state.

## The constraint catalog

| Constraint | Enforces | Reach for it when |
|---|---|---|
| `NOT NULL` | the field is always known | almost always — start here and justify exceptions |
| `FOREIGN KEY` | the referenced record exists | every relationship, always |
| `UNIQUE` | no two records share this value | natural keys, and as a race guard |
| `CHECK` | a value or cross-field rule | ranges, signs, mutual exclusion, format |
| `PRIMARY KEY` | identity | every table, no exceptions |
| exclusion | no two records overlap | bookings, subscriptions, shifts, prices with validity ranges |

**Uniqueness is your concurrency primitive.** A read-then-insert can be passed by two concurrent requests; a unique constraint cannot. Declare the constraint and use an upsert rather than checking first. The same applies to counters — one atomic conditional update beats read-modify-write — and to duplicate processing, which a unique index on an idempotency key stops dead.

**Foreign key delete actions** are a design decision per relationship, not a default to accept: `CASCADE` for parts that can't exist alone (order lines), `RESTRICT`/`NO ACTION` for references that should block the delete (a currency still in use), `SET NULL` only where the child genuinely survives orphaned.

## Soft delete, done properly

Adding `deleted_at` breaks two things that nobody notices until production.

**Uniqueness must be re-scoped to live rows**, or a deleted user can never re-register:

```sql
CREATE UNIQUE INDEX CONCURRENTLY users_email_live
  ON users (email) WHERE deleted_at IS NULL;
ALTER TABLE users DROP CONSTRAINT users_email_key;
```

Order and syntax both matter here. Build the replacement **first**, so uniqueness is never unenforced — drop first and a concurrent double-signup slips a duplicate in that the new index then refuses to build over. Use `DROP CONSTRAINT`, not `DROP INDEX`: the index behind a `UNIQUE` constraint is owned by it, and `DROP INDEX users_email_key` fails with *"cannot drop index … because constraint … requires it"*. And `CONCURRENTLY` because a plain `CREATE UNIQUE INDEX` locks the table against writes for the whole build — on a large `users` table that is an outage. `CONCURRENTLY` can't run inside a transaction block, so this is two migration steps, and a failed build leaves an `INVALID` index to drop and retry.

MySQL has no partial index — see the generated-column recipe in `engine-map.md`.

**The filter must live in exactly one place.** A view or a single repository method, never 200 call sites:

```sql
CREATE VIEW users_live AS SELECT * FROM users WHERE deleted_at IS NULL;
```

Every forgotten filter leaks deleted rows into a report. And remember the rows still occupy every index — soft delete trades storage and query discipline for undo.

## Tenant scoping

Make the tenant part of the key, lead every index with it, and let the engine enforce the filter:

```sql
CREATE TABLE contacts (
  tenant_id int NOT NULL REFERENCES tenants(id),
  id int GENERATED ALWAYS AS IDENTITY,
  email text NOT NULL,
  PRIMARY KEY (tenant_id, id),
  UNIQUE (tenant_id, email)
);

ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON contacts
  USING (tenant_id = current_setting('app.tenant_id')::int);
```

**`FORCE` is not optional, and leaving it out is a silent cross-tenant leak.** Postgres exempts the table *owner* from row security, and in most deployments the application role owns the tables its own migrations created — so with `ENABLE` alone the policy does nothing and every tenant reads every row. Policies never apply to superusers or roles with `BYPASSRLS` at all. Verify by connecting as the application role, setting one tenant, and confirming a `SELECT` returns only that tenant's rows; if you get all of them, `FORCE` is missing.

Child tables carry `tenant_id` too, so a join can't cross tenants. Row-level security turns "we always remember the `WHERE`" from a promise into an enforced rule. If you set the tenant via a session variable, note that a transaction-pooled connection pool requires `SET LOCAL` inside the transaction — otherwise the setting leaks between requests, which is the exact leak you were preventing.

## Validity ranges for history

When the question is "what was true on date X", store the range and let the engine forbid overlaps:

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE product_prices (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id int NOT NULL REFERENCES products(id),
  price_cents bigint NOT NULL CHECK (price_cents >= 0),
  valid_from timestamptz NOT NULL,
  valid_to timestamptz,
  CONSTRAINT no_overlap EXCLUDE USING gist (
    product_id WITH =, tstzrange(valid_from, valid_to) WITH &&
  )
);
```

Two details this fails on if you change them. **`btree_gist` is required** — without it `product_id WITH =` errors with *"data type integer has no default operator class for access method gist"*, because plain equality isn't a GiST operator by default. And the range columns must be **`timestamptz`, not `timestamp`**: `tstzrange()` takes `timestamptz`, so `timestamp` arguments force a cast whose result depends on the session `TimeZone`, making the expression `STABLE` rather than `IMMUTABLE` — Postgres rejects it with *"functions in index expression must be marked IMMUTABLE."*

Current price is `WHERE valid_to IS NULL`. Without the exclusion constraint this table will eventually contain two prices valid on the same day, and no query will tell you which is right.
