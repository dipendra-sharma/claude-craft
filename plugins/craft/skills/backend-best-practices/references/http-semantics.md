# HTTP semantics for REST APIs

The parent skill's §5–§9 decide the *conventions* (paths, envelope, error shape, status table). This is the layer beneath them: what the protocol itself gives you, and the headers and codes that most APIs leave unset until a cache serves one user's data to another or a client can't tell "retry" from "stop". `references/api-conventions.md` is the worked example; this file is the checklist behind it.

---

## 0. Method safety and idempotency — from the spec, not intuition

Everything the parent skill says about retries (§11) and idempotency (§10) rests on this table, so get it from RFC 9110 rather than from memory:

| | Safe | Idempotent |
|---|---|---|
| `GET`, `HEAD`, `OPTIONS`, `TRACE` | yes | yes |
| `PUT`, `DELETE` | no | **yes** |
| `POST`, `PATCH` | no | **no** |

- **Safe means no side effect the client is accountable for.** Browsers, crawlers, prefetchers and link-preview bots will replay safe methods uninvited — a `GET` that mutates will be fired by something you don't control.
- **`PUT` is a full replacement.** Sending a partial body to `PUT` and having the server merge it is a lost-update bug wearing the wrong verb; that's `PATCH`.
- **`PATCH` carries no idempotency guarantee.** Use a declared patch media type with **absolute** values (`application/merge-patch+json`, `application/json-patch+json`) — never relative ones like `{"balance": "+10"}`, which double-apply on the retry that a timeout makes inevitable. Gate it with `If-Match` (§2) or an idempotency key (parent §10) when the effect is not naturally idempotent.
- **A second `DELETE` of an already-gone resource returns `204` or `404`**, never a `409` or a `500` — the *state* the caller asked for is the state that exists.

---

## 1. Status codes beyond the basic table

The parent table covers 200/201/204, 400/401/403/404/409/422/429 and 5xx. Add these when the situation arises, and never invent semantics for a code:

- **`202 Accepted`** — the work is queued, not done. Return a `Location` to a status resource the client can poll (parent §16).
- **`304 Not Modified`** — the answer to a conditional GET whose `ETag`/`Last-Modified` still matches. No body; repeat the caching headers.
- **`404` instead of `403` for resources the caller may not know exist** — a `403` on `/users/8123/invoices` confirms user 8123 exists. Hide existence when enumeration is a risk (parent §18).
- **`405 Method Not Allowed`** — the path exists, the verb doesn't; must carry an `Allow: GET, POST` header.
- **`406 Not Acceptable`** / **`415 Unsupported Media Type`** — the client's `Accept` or `Content-Type` can't be served; don't silently guess a format.
- **`410 Gone`** — a sunset version or a deliberately removed resource (§8 below); tells clients not to retry.
- **`412 Precondition Failed`** — an `If-Match` didn't match: someone else changed the resource (§2 below). **`428 Precondition Required`** — the write must carry `If-Match` and didn't.
- **`413 Content Too Large`** — the body exceeds your limit (§7 below). Enforce it at the proxy *and* the app.
- **`501 Not Implemented`** — recognised but unsupported; **`503 Service Unavailable`** with `Retry-After` when load-shedding (parent §11, §16).

---

## 2. Caching and conditional requests

Parent §17 is about the cache you *run*; this is about the cache you *instruct* — browsers, CDNs, and proxies obey headers, and the default when you send none is "whatever the intermediary feels like."

- **Every response gets a deliberate `Cache-Control`.** Authenticated or per-user data: `Cache-Control: no-store` (or `private, max-age=N` when the browser alone may keep it). Shared public data: `public, max-age=N, stale-while-revalidate=M`. A missing directive on a per-user response is how a CDN serves one customer's account page to another.
- **`no-cache` does not mean "don't cache."** It means "store, but revalidate before use." Use `no-store` when you mean never store.
- **`ETag` + `If-None-Match` for cheap revalidation.** Compute a strong ETag from a version column or a content hash; respond `304` when it matches. Weak ETags (`W/"…"`) are fine for freshness, not for concurrency control.
- **`If-Match` for optimistic concurrency.** A client that read `ETag: "v7"` sends `If-Match: "v7"` on its PUT/PATCH; a mismatch is `412`, and the client re-reads instead of overwriting a change it never saw. This is parent §12's `version` column surfaced in HTTP. Require it with `428` on resources where lost updates matter.
- **`Vary` names what the response depends on** — `Accept-Encoding`, `Accept`, `Origin` when echoing CORS origins. Never rely on `Vary: Authorization` or `Vary: Cookie` to keep per-user data out of a shared cache; use `private`/`no-store`.
- **`Last-Modified` / `If-Modified-Since`** — second-resolution and weaker than ETags; use them alongside, not instead.
- **Don't cache errors or `POST` responses** unless you have decided to; a cached `500` outlives the outage.

---

## 3. Cookies

Parent §18 gives the three flags; the rest of the surface:

- **Session cookie = opaque id or signed token, nothing else.** ~4 KB limit, sent on every request, visible to the user. State lives server-side (parent §13).
- **Attributes, every time:** `Secure; HttpOnly; SameSite=Lax` minimum (`Strict` when no cross-site navigation needs the session; `None` only with `Secure` and a CSRF story); `Path=/` and *no* `Domain` unless subdomains genuinely share the session; `Max-Age` over `Expires`.
- **Use the `__Host-` prefix** for session cookies: the browser enforces `Secure`, no `Domain`, `Path=/`, so a subdomain can't plant a cookie your app trusts.
- **Rotate on privilege change** — login, logout, password or role change issue a new session id and invalidate the old (session fixation). Server-side expiry, not just cookie expiry.
- **Cookies vs bearer tokens:** browser clients → cookie with the flags above and CSRF protection; non-browser clients → `Authorization: Bearer` with short-lived tokens. Don't offer both on the same endpoint without deciding which wins.

---

## 4. Security headers

For a JSON API these are five lines of middleware; for anything that returns HTML (docs, error pages, redirects) they are mandatory.

- **`Strict-Transport-Security: max-age=31536000; includeSubDomains`** — after the first HTTPS visit the browser refuses HTTP. Add `preload` only once every subdomain is HTTPS forever.
- **`X-Content-Type-Options: nosniff`** — stops a browser from executing a JSON or upload response as script.
- **`Content-Security-Policy`** — on HTML responses a real policy; on a pure API `default-src 'none'; frame-ancestors 'none'` so an error page can't be framed or made to load anything. `frame-ancestors` replaces `X-Frame-Options`.
- **`Referrer-Policy: strict-origin-when-cross-origin`** (or `no-referrer`) — keeps URLs with ids or tokens out of third-party logs.
- **`Permissions-Policy`** — disable browser features the response doesn't need (`camera=(), geolocation=()`).
- **Don't announce the stack** — drop `Server`, `X-Powered-By`, framework version headers; they are free reconnaissance.

---

## 5. CORS

- **Preflight is a real request.** Non-simple requests (custom headers, JSON `Content-Type`, `PUT`/`DELETE`) trigger an `OPTIONS` first. Answer it fast, without auth, and cache it with `Access-Control-Max-Age`.
- **Credentials need an exact origin.** `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` is rejected by browsers; echo an origin from an allowlist and add `Vary: Origin`. Never reflect the request's origin unchecked — that is `*` with credentials by another route.
- **Expose the headers clients need.** Only a handful of response headers are readable cross-origin by default; `ETag`, `Location`, `X-Request-Id`, `RateLimit-*`, `Retry-After` need `Access-Control-Expose-Headers`.
- **CORS is not authorization.** It protects browser users from other sites; a `curl` ignores it. Every endpoint still authenticates and authorizes (parent §18).

---

## 6. Rate limiting, tracing, and the other headers

- **Rate limits are visible.** On every response, or at least on `429`: the IETF `RateLimit` / `RateLimit-Policy` fields or the de-facto `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`. Pick one set. Always `Retry-After` on `429` and `503`. Key limits per user or API key before per IP; NAT and mobile carriers share IPs.
- **Correlation:** accept and echo `X-Request-Id` (generate one if absent) and propagate W3C `traceparent`/`tracestate` to every downstream call so traces stitch across services (parent §19). Put the id in every error body (parent §7).
- **`Location`** on `201` (the new resource) and `202` (the status resource). **`Content-Location`** when a `PUT`/`PATCH` returns the updated representation.
- **`Link`** for pagination when clients shouldn't parse your envelope: `Link: <…?cursor=abc>; rel="next"` (parent §6).
- **`Content-Disposition: attachment; filename="…"`** for downloads; sanitize the filename. Serve user-uploaded files from a separate origin so a crafted file can't run in your site's context.
- **`Deprecation` / `Sunset`** — see §8 below.
- **`Prefer: return=minimal`** lets a client ask for `204` instead of the full representation on writes; honor it with `Preference-Applied`.

---

## 7. Sizing: requests, responses, and endpoint granularity

- **Cap request bodies** at the proxy and the app (`413`), and bound JSON depth and key count — a 2 MB, 10,000-level-deep document is a parser DoS before any validation runs (parent §8, §16). Uploads bypass the API entirely (parent §8, object storage).
- **Cap response pages** (parent §6) and offer **sparse fieldsets** — `?fields=id,name,status` against an allowlist — so mobile clients stop downloading 40 fields to render three.
- **Expansion beats chatty clients.** `?include=customer,items` (allowlisted, one level deep, batch-loaded so it doesn't reintroduce N+1) turns five round-trips into one. The alternative failure is the god-endpoint that returns everything to everyone; sparse fieldsets are the counterweight.
- **Bulk endpoints return per-item results.** `POST /orders/bulk` with 100 items answers `200` with one status per item, not a single `400` because item 73 was invalid. Cap the batch size; make each item idempotent (parent §10).
- **Compress on the way out** — `Accept-Encoding` → `gzip`/`br` at the proxy for JSON above ~1 KB; skip already-compressed bytes (images, archives).
- **Large results are a stream or a job.** Chunked transfer or NDJSON for exports a client consumes incrementally; otherwise `202` + a status resource + a download URL (parent §16). Never build a 200 MB array in memory to serialize it.
- **Size the endpoint to the client's screen, not the table.** One request per view is the target; if a page needs eight calls, add an expansion or a purpose-built read endpoint (a BFF), not a client-side join.

---

## 8. Versioning and deprecation

- **Define "breaking" once:** removing or renaming a field, changing a type or its meaning, tightening validation, changing a status or error code, changing default sort or pagination. Adding an optional field or a new endpoint is not.
- **Pick one strategy and its trade-off.** URI (`/v1/orders`): visible, cacheable, trivially testable, one deploy per version. Header (`Accept: application/vnd.acme.v2+json` or `API-Version: 2`): stable URLs, but needs `Vary` and is invisible in logs and browser tabs. Date-pinned (`Acme-Version: 2026-06-01`, Stripe-style): per-account pinning with many live versions — powerful and expensive to maintain.
- **Signal before you remove.** `Deprecation: @1767225599` (the date it became deprecated) and `Sunset: Wed, 30 Jun 2027 23:59:59 GMT` on every response of the old version, plus `Link: <docs-url>; rel="deprecation"`. Log usage per version per consumer so you know who hasn't moved.
- **After sunset, `410 Gone`** with an error body pointing at the replacement — not a silent `404`, not a redirect that changes semantics.
- **Never version by mutating in place.** A "v1" whose behaviour changed is two APIs with one name.

---

## 9. Path hygiene beyond the naming rules

- **Nothing sensitive in the URL** — no tokens, emails, or PII in path or query. URLs land in proxy logs, browser history, `Referer` headers, and screenshots. Use the body or headers.
- **Opaque ids** (UUID/ULID), not sequential integers — sequential ids make enumeration and IDOR guessing trivial (parent §18).
- **No file extensions** (`/report.json`); negotiate with `Accept`.
- **Trailing slashes:** pick one form, redirect (`308`) or reject the other; don't serve both as distinct resources.
- **Query parameters are for filtering, sorting, paging, and shaping** (`?status=`, `?sort=-createdAt`, `?cursor=`, `?fields=`, `?include=`) — every one allowlisted (parent §1) and documented once (parent §9).
