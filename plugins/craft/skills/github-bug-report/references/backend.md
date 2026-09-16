# Backend / API bug — environment & version fields

Collect these for the **Environment** section. Ask for anything missing; assume
production unless the user says otherwise.

- **Service / API name** — which service or microservice.
- **Environment** — production / staging / dev / local.
- **Service version** — release tag, build number, or commit SHA (the single
  most useful field for locating a regression).
- **Endpoint / operation** — method + path, e.g. `POST /api/v2/checkout`, or the
  job/consumer name for async work.
- **Runtime** — language + version if relevant (Node 20, JVM 17, Python 3.12, Go 1.22).
- **Region / instance** — if multi-region or the bug is host-specific.
- **Datastore** — DB/engine + version if the bug touches persistence.

## Evidence worth capturing

- **HTTP status + response body** returned to the client.
- **Full stack trace** (in a collapsible block).
- **Trace / correlation / request ID** — lets the dev pull logs directly.
- **Request payload** (redact secrets/PII) and relevant headers.
- **Timestamp (with timezone)** of a real occurrence — anchors the log search.
- **Log excerpt** or a link to the log/APM dashboard (Datadog, Grafana, Sentry).

## Environment block example

```markdown
## Environment
- **Service:** checkout-api
- **Environment:** production
- **Version:** v4.2.1 (commit `a1b2c3d`)
- **Endpoint:** `POST /api/v2/checkout`
- **Runtime:** Node 20.11
- **Region:** ap-south-1
- **Trace ID:** `4bf92f3577b34da6a3ce929d0e0e4736`
- **Occurred at:** 2026-07-14 09:32 IST
```
