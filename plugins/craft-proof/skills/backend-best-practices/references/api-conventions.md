# Example API convention set

**This is one worked example, not a mandate.** Copy it as a starting point for a greenfield project, or read it to model your own. The value of the parent skill's principle §9 is *picking a consistent set and documenting it* — not adopting this exact one. Match an existing project's established conventions over anything here.

The choices below are internally consistent and deliberately avoid a generic `data` key (see the envelope note). Adapt freely: a gRPC or GraphQL service maps these ideas differently, and a team with a house style should keep it.

---

## 1. Resource naming & URLs

- Plural nouns, resource-oriented: `/orders`, `/orders/{id}`, `/orders/{id}/items`.
- The HTTP method carries the action; the path never contains a verb (`/orders/{id}`, `DELETE` — not `/deleteOrder`).
- Keep nesting to one level. Go flat with query filters when you'd need to go deeper: `/items?orderId={id}` over `/orders/{id}/items/{itemId}/adjustments`.
- Lowercase, hyphen-separated multi-word paths: `/purchase-orders`.
- Genuinely non-CRUD actions may use a sub-resource verb sparingly: `POST /orders/{id}/cancel`.

## 2. Single-resource response — unwrapped

Return the resource object directly. Put cross-cutting metadata in headers, not a body envelope.

```
GET /orders/123  →  200
```
```json
{
  "id": "123",
  "status": "confirmed",
  "totalMinor": 4999,
  "currency": "INR",
  "createdAt": "2026-07-14T09:30:00Z"
}
```
Relevant headers: `ETag`, `Location` (on create), `X-Request-Id`.

*Why no wrapper:* nothing to unwrap, and a single resource rarely needs sibling top-level metadata. If you later find you want a uniform top-level object everywhere, switch to a resource-named key (`{ "order": {…} }`) — but never a generic `data`.

## 3. Collection response — wrapped, never a bare array

```
GET /orders?limit=20&cursor=eyJpZCI6MTIzfQ  →  200
```
```json
{
  "items": [
    { "id": "124", "status": "pending", "totalMinor": 1299, "currency": "INR", "createdAt": "2026-07-14T10:00:00Z" }
  ],
  "pagination": {
    "nextCursor": "eyJpZCI6MTQ0fQ",
    "hasMore": true
  }
}
```

- `items` holds the page; `pagination` holds cursor state. (Swap `items` for a resource-named key like `orders` if you prefer — just be consistent.)
- **Never** return a bare top-level array — you can't add metadata later without breaking every client.
- Default to **cursor/keyset** pagination. `nextCursor: null` (or absent) + `hasMore: false` means the last page. Include `prevCursor` only if you support backward paging.
- Server clamps `limit` to a documented maximum.
- Filtering/sorting via query params, consistent across endpoints: `?status=pending&sort=-createdAt`.

## 4. Error response — RFC 9457 Problem Details

One shape for every error, `Content-Type: application/problem+json`:

```
POST /orders  →  422
```
```json
{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation failed",
  "status": 422,
  "detail": "One or more fields are invalid.",
  "instance": "/orders",
  "code": "VALIDATION_ERROR",
  "requestId": "01J...",
  "errors": [
    { "field": "totalMinor", "message": "must be a positive integer" }
  ]
}
```

- `code` is a stable machine-readable string clients branch on; `title`/`detail` are human-facing and may be reworded freely. Getting this split wrong — clients parsing `detail` — is what makes error messages unchangeable later. `requestId` correlates with server logs/traces (§19).
- `errors[]` carries field-level detail for validation failures; omit it otherwise.
- Never leak stack traces, SQL, or internal hostnames (§7, §18).
- A hand-rolled `{ "error": { "code", "message", "requestId", "fields" } }` is a fine alternative — just pick one shape and use it everywhere.

## 5. Field conventions

- **Casing:** `camelCase` everywhere (pick `snake_case` instead if your ecosystem leans that way — just don't mix).
- **Timestamps:** ISO-8601 in UTC with `Z` (`2026-07-14T09:30:00Z`). Never epoch-only or local time.
- **Money:** integer minor units (`totalMinor`) or a decimal type, plus an explicit `currency` — never a float (`coding-best-practices` §9).
- **Enums:** documented lowercase strings (`"status": "confirmed"`), never bare integers.
- **IDs:** strings, even if numeric underneath — lets you migrate to UUID/ULID without a breaking type change.
- **Null vs omit:** pick one policy. Recommended: omit fields that don't apply; use `null` only when "explicitly empty" is meaningful and distinct from "absent".

## 6. Status-code mapping

Every endpoint follows the same table so clients can branch on status alone:

| Outcome | Code |
|---|---|
| Read / update success | `200` |
| Create success | `201` (+ `Location`) |
| Success, no body | `204` |
| Malformed request | `400` |
| Not authenticated | `401` |
| Authenticated, not allowed | `403` (or `404` when the resource's existence must stay hidden) |
| Resource not found | `404` |
| Conflict (duplicate, version, idempotency key still in flight) | `409` |
| Validation failed | `422` |
| Rate limited | `429` (+ `Retry-After`) |
| Server / dependency failure | `500` / `502` / `503` |

## 7. Cross-cutting request conventions

- **Idempotency:** unsafe non-idempotent writes accept an `Idempotency-Key` header; a replay returns the original result, and a key whose request is still in flight gets `409` (§10).
- **Correlation:** accept and propagate `X-Request-Id` (generate one if absent); echo it in responses and errors, and thread it through downstream calls and logs (§19).
- **Versioning:** URI prefix (`/v1/...`) or a version header — decide once. Additive changes don't bump the version; breaking changes do (§5).
- **Content negotiation:** `application/json` for success, `application/problem+json` for errors; require/validate `Content-Type` on write requests.

## 8. The request shape is not the response shape

A write payload and the resource you hand back are two different types that happen to overlap today. Modelling them as one type is what later forces every server-owned field to be optional.

```
POST /orders          ← { "customerId": "c_88", "items": [...], "currency": "INR" }
201 + Location        → { "id": "123", "customerId": "c_88", "items": [...], "currency": "INR",
                          "status": "pending", "totalMinor": 4999, "createdAt": "…", "updatedAt": null }
```

- The **input** carries only what the caller is allowed to set. Server-owned fields (`id`, `status`, `totalMinor`, `createdAt`) are not merely ignored when a client sends them — they are rejected, because silently dropping them is indistinguishable from accepting them and is how mass assignment gets through (parent §8).
- The **output** is the full resource. If you reuse the input type for it, `id` and `createdAt` have to be declared optional to satisfy the create path — and now every *reader* has to null-check an `id` that is in fact always present.
- Keep `CreateOrder`, `UpdateOrder` and `Order` distinct even while they are 90% identical. They diverge permanently the first time you add one computed field, and splitting them later is a breaking change you'd rather not schedule.
- The same split is why `PATCH` bodies are their own type: every field optional there is meaningful ("not supplied" ≠ "set to null"), which is exactly the ambiguity the null-vs-omit policy in §5 has to settle.
