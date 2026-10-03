# Protocol-specific traps: gRPC and GraphQL

The parent skill's API sections (§5–§9) assume plain HTTP/REST. These protocols keep every backend rule — parameterize, bound, time out, authorize per resource — and add failure modes of their own. Read the section for the protocol in front of you.

---

## gRPC

- **Deadlines, not timeouts.** The client sets a deadline on every call; the server reads it from the context and propagates the *remaining* budget to each downstream call. A server that ignores the deadline keeps working after the client gave up — wasted capacity and orphaned side effects. Check for cancellation before each expensive step.
- **Status codes carry the contract.** Map outcomes to the canonical codes and hold the mapping: `INVALID_ARGUMENT` (bad input), `NOT_FOUND`, `ALREADY_EXISTS`, `UNAUTHENTICATED` vs `PERMISSION_DENIED`, `FAILED_PRECONDITION` (state won't allow it; don't retry until fixed), `ABORTED` (concurrency conflict; retry the whole read-modify-write), `RESOURCE_EXHAUSTED` (quota/rate limit), `UNAVAILABLE` (transient; safe to retry), `DEADLINE_EXCEEDED`, `INTERNAL`. Returning `UNKNOWN`/`INTERNAL` for client faults erases the difference between "retry" and "fix your request."
- **Retry only `UNAVAILABLE` (and `ABORTED` at the transaction level), only on idempotent methods.** A blind retry on `DEADLINE_EXCEEDED` double-applies a write that actually landed (parent §10, §11). Declare retry policy per method in the service config, not ad hoc in callers.
- **Proto evolution.** Never reuse or renumber a field; mark removed numbers and names `reserved`; never change a field's type; add fields as optional and let unknown fields round-trip. Renaming is wire-safe but breaks JSON mapping and generated code — treat it as breaking for any client using either.
- **Message size and streaming.** The default max receive size is 4 MB, so a "list everything" response fails at scale — paginate or stream. Streaming needs flow control: bound buffered messages and apply backpressure, or a slow consumer OOMs the server.
- **Load balancing is L7.** HTTP/2 multiplexes on one long-lived connection, so an L4/TCP balancer pins each client to one backend forever. Use client-side balancing, a gRPC-aware proxy, or a mesh; set a max connection age so connections rebalance.
- **Health and keepalive.** Implement the standard health service (`grpc.health.v1`) for readiness; configure keepalive so dead peers are detected without waiting for a deadline.
- **Error details, not error strings.** Attach `google.rpc` detail messages (`BadRequest` field violations, `RetryInfo`, `ErrorInfo` with a stable reason) instead of making clients parse `message`.
- **Authorize per method and per resource** — an interceptor knows the caller and the method; only the handler knows the resource, so both check (parent §18).

---

## GraphQL

- **N+1 is the default.** Resolvers run per parent object, so `posts { author { name } }` issues one author query per post. Batch and cache per request with a DataLoader (one `WHERE id = ANY($1)` per level); never let a resolver issue unbatched queries.
- **Bound the query.** Clients write arbitrary shapes, so one request can be exponential work. Enforce a depth limit, a complexity/cost budget computed before execution, alias and field-duplication limits, and a per-operation timeout. Prefer persisted or allowlisted operations for public clients; gate introspection in production.
- **Authorize in the business layer, not per route.** The same field is reachable through many paths, so a check on one query misses the others. Authorization lives on the type/field resolver or in the data layer, keyed on the caller and the *specific* object (parent §18).
- **Errors have a contract too.** Transport is usually `200` even on failure, so put a stable machine-readable `extensions.code` on every error (`UNAUTHENTICATED`, `FORBIDDEN`, `BAD_USER_INPUT`, `NOT_FOUND`, `INTERNAL`), never leak stack traces or SQL into `message`, and decide once whether partial data is returned alongside errors (parent §7).
- **Pagination is connections.** Cursor-based `edges`/`node`/`pageInfo` with a server-clamped `first`/`last`; never an unbounded list field (parent §6).
- **Mutations are still writes.** Accept an idempotency key or `clientMutationId`, return the changed object so clients can update caches, and keep each mutation to one business action (parent §10).
- **Schema evolution.** Adding fields and types is safe; removing or retyping is breaking. Use `@deprecated(reason:)`, watch field usage before removal, and never reuse a name with a different type.
- **Subscriptions are long-lived connections** — bound them per client, authenticate on connect *and* re-check on each event, and design for reconnect with a cursor.
- **The gateway is a trust boundary.** In a federated or stitched setup, subgraphs must not trust headers the gateway didn't sign; propagate the caller identity explicitly and verify it.
