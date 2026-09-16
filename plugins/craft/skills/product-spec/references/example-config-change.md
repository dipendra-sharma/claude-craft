---
title: Raise Bulk Export Row Cap
id: bulk-export-row-cap
status: Approved
owner: Dan Whitfield
date: 2026-08-11
type: config-change
surfaces: backend, frontend
audience: internal
---

# Raise Bulk Export Row Cap — Product Spec

A PRD with SRS-level requirements and acceptance criteria.

> Minimum-viable example: a tiny change, so §5, §6, §10, §14, §15, and §16 are omitted. The unhappy
> path (§9) and acceptance criteria (§12) are *not* optional at any size — they're what make a small
> change actionable. Section numbers keep their template values; the gaps are intentional. Delete this
> blockquote in a real spec.

## 1. TL;DR

Raise the row cap on the internal bulk export from 10,000 to 100,000 rows. Ops analysts currently
split large exports into a dozen runs by hand, which is slow and error-prone. This is a limit change
plus honest behavior at the new boundary — no new export features.

## 2. Problem & Why Now

The 10,000-row cap dates from a slower export path we replaced last quarter, so the limit no longer
matches what the system can do. Ops runs roughly 40 exports a week, and about a third hit the cap and
must be split and stitched together in a spreadsheet. Two incidents last month traced back to a
stitched export with a duplicated page.

## 3. Goals & Success Metrics

- **Goal:** Ops completes a large export in one run.
  - **Metric:** Exports that hit the row cap — baseline `31%` → target `<5%` within two weeks of rollout — **source:** `AE-1` (new).
- **Goal:** No regression in export reliability at the higher cap.
  - **Metric:** Exports that fail or time out — baseline `0.4%` → target stays `≤0.5%` through rollout — **source:** existing `export_job_failed` event, Ops Tooling dashboard.

## 4. Non-Goals

- Do not change who can run an export or what columns it includes.
- Do not add scheduled or recurring exports.
- Do not change the export file format.
- Do not raise the cap for the customer-facing export; internal only in this work.

## 7. Existing System & Constraints

- **Current behavior:** An export request above 10,000 rows is rejected up front with a message naming
  the limit. Below the limit, the file is produced and emailed as a link.
- **Must not break:** Existing exports under 10,000 rows behave exactly as they do today, including the
  email link and its expiry.
- **Dependencies / integrations:** The Ops console triggers exports; the notification service delivers
  the link.
- **Data already in place:** Export history and previously generated files are untouched by this change.

## 8. Functional Requirements

- **FR-1** — Raised cap — *Must* — An internal export of up to 100,000 rows is accepted and completes in one run.
- **FR-2** — Accurate limit messaging — *Must* — A request above the new cap is rejected with a message naming the current limit and the row count requested.
- **FR-3** — Progress visibility — *Should* — While an export above 10,000 rows is running, the requester can see it is still in progress rather than an idle screen.

## 9. Edge Cases & Error Behavior

- **EC-1** — Request is between 100,001 and any larger number — Rejected before work starts, with the same message as `FR-2`; no partial file is produced.
- **EC-2** — Export exceeds the time budget mid-run — The run is stopped, the requester is told it did not complete and that the limit was not the cause, and no partial file is delivered.
- **EC-3** — Requester triggers the same export twice — The second request is accepted as its own run; both links are delivered and neither cancels the other.
- **EC-4** — Cap is lowered again while a large export is running — The in-flight run finishes at the cap it started under.

## 11. Analytics & Tracking Events

- **AE-1** — `export_requested` — fires when an export is submitted — props: `row_count`, `outcome` (`accepted` \| `rejected_over_cap`), `cap_in_effect` — feeds: metric "exports that hit the row cap", and the row-count distribution that tells us whether 100,000 is the right number.

**Where the numbers are read:** existing Ops Tooling dashboard — **read by:** Dan, weekly for the first month.

## 12. Acceptance Criteria

**FR-1 — Raised cap**
- **AC-FR-1.1** — Given an internal requester, When they request an export of 100,000 rows, Then it is accepted and a complete file with 100,000 rows is delivered in one run.
- **AC-FR-1.2** — Given an export of 9,000 rows, When it is requested, Then it behaves exactly as before the change, including the delivered link and its expiry.

**FR-2 — Accurate limit messaging**
- **AC-FR-2.1** — Given a request for 120,000 rows, When it is submitted, Then it is rejected with a message stating the 100,000-row limit and the 120,000 rows requested.

**FR-3 — Progress visibility**
- **AC-FR-3.1** — While an export above 10,000 rows is running, the system shall show the requester that the run is in progress.

**EC-1 — Over the new cap**
- **AC-EC-1.1** — If a request exceeds the cap, then the system shall reject it before starting work and produce no file.

**EC-2 — Time budget exceeded**
- **AC-EC-2.1** — If a run exceeds its time budget, then the system shall stop it, deliver no partial file, and tell the requester it did not complete and that the row cap was not the cause.

**EC-3 — Duplicate request**
- **AC-EC-3.1** — Given an export already running, When the same export is requested again, Then both runs complete and both links are delivered.

**EC-4 — Cap lowered mid-run**
- **AC-EC-4.1** — While a run is in flight, the system shall complete it under the cap that was in effect when it started.

## 13. Rollout & Migration

- **Flag / toggle:** Export row cap value — **default:** 10,000 (unchanged) — **who gets it first:** the Ops team's own accounts.
- **Rollout sequence:** Ops team → all internal users, advancing once ten exports above 10,000 rows have
  completed with no failures.
- **Kill switch:** Setting the cap back to 10,000 restores today's behavior immediately; in-flight runs
  finish under the old cap per `EC-4`, and already-delivered files stay valid.
- **Existing users / data:** No migration. Export history and existing files are unaffected.
- **Old path:** No old path to retire — this is a limit value, not a new flow.

## 18. Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-11 | Dan Whitfield | Initial version. Approved in Ops review the same day. |
