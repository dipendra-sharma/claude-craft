---
title: Offline Reading Mode
id: offline-reading-mode
status: In Review
owner: Priya Nair
reviewers: Sam Okonkwo (Eng), Lena Fischer (Design)
date: 2026-08-14
type: brownfield
surfaces: mobile
audience: consumer
---

# Offline Reading Mode — Product Spec

A PRD with SRS-level requirements and acceptance criteria.

## 1. TL;DR

Let readers save articles for offline access in our existing mobile news app. Today the app shows a
blank error when the network drops, and commuters on the metro lose their place mid-article. This adds
an explicit "Save for offline" action and an Offline library so saved articles open instantly with no
connection.

## 2. Problem & Why Now

A third of daily sessions start on transit, where connectivity is intermittent. When the network
drops, the reader view fails and the article is lost — our top support complaint this quarter and a
measurable driver of session abandonment. A competitor shipped offline reading last month; we are now
the only major reader in the category without it.

## 3. Goals & Success Metrics

- **Goal:** Readers can finish articles regardless of connectivity.
  - **Metric:** Sessions ending in a network-error screen — baseline `8%` → target `<2%` by end of Q3 — **source:** existing `reader_error_shown` event, Reader Reliability dashboard.
- **Goal:** Drive habitual saving.
  - **Metric:** Weekly active subscribers who save ≥1 article — baseline `0` → target `15%` within 60 days of launch — **source:** `AE-1` (new).
- **Goal:** Saving is reliable enough to trust.
  - **Metric:** Save attempts that fail — no baseline (new behavior) → target `<1%` of attempts by end of Q3 — **source:** `AE-3` (new).

## 4. Non-Goals

- Do not add offline support for video or audio content in this phase.
- Do not change the existing online reading or paywall flow.
- Do not add cross-device sync of the offline library.
- Do not make saved articles available to free (unentitled) readers in this phase.

## 5. Users & Scenarios

- **User / role:** Daily commuter (subscriber) — **wants to** queue articles while on Wi-Fi and read
  them on the metro with no signal.
- **Primary journey:** On Wi-Fi, the reader taps "Save for offline" on an article. Later, with no
  connection, they open the Offline library, tap a saved article, and read it in full instantly.

## 6. Permissions & Roles

- **Entitled reader (active subscription)** — can save, browse, open, and remove offline articles.
- **Free / lapsed reader** — cannot save. The save action is visible but inactive, and tapping it opens
  the existing subscribe screen with the article retained behind it.
- **Reader whose subscription lapses while holding saved articles:** see `EC-5` — copies are locked,
  not deleted.

## 7. Existing System & Constraints

- **Current behavior:** Articles render in an online-only reader view; a network drop shows a generic
  error screen with no recovery.
- **Must not break:** The existing online reader, the paywall gate, and the bookmark (read-later)
  feature, which is distinct from offline save and stays server-side.
- **Dependencies / integrations:** Reuses the current article content service and the account session;
  saving is allowed only for entitled readers.
- **Data already in place:** Existing bookmarks stay untouched and are not migrated into the offline
  library — a reader can hold both, independently, for the same article.

## 8. Functional Requirements

**Saving**
- **FR-1** — Save for offline — *Must* — An entitled reader can save the currently open article for offline access.
- **FR-2** — Remove saved article — *Must* — A reader can remove a saved article from the Offline library.
- **FR-3** — Save state indicator — *Should* — An article already saved shows a "Saved" state instead of the save action.

**Reading offline**
- **FR-4** — Offline library — *Must* — A reader can browse all saved articles in one place, newest save first.
- **FR-5** — Open offline — *Must* — A saved article opens and renders fully with no network connection.
- **FR-6** — Storage limit notice — *Could* — When saved articles approach the storage cap, the reader is told and prompted to remove some.

## 9. Edge Cases & Error Behavior

- **EC-1** — Reader taps save with no connection — The article is not saved, and the reader is told saving needs a connection; the article stays open and the save action stays available.
- **EC-2** — Saved article is updated or unpublished after saving — The saved copy stays readable and shows the date it was saved; the next time it is opened with a connection, the newer version replaces it. An unpublished article stays readable with a note that it is no longer available online.
- **EC-3** — Device runs out of space mid-save — The save fails cleanly with no partial article in the library, and the reader is told space ran out.
- **EC-4** — Offline library is empty (first visit) — The library explains how to save an article instead of showing a blank screen.
- **EC-5** — Account session ends or subscription lapses — Saved copies become unreadable and the library prompts the reader to sign in or resubscribe. Copies are retained, not deleted, and become readable again once entitlement is restored.
- **EC-6** — Reader triggers save twice for the same article — Exactly one copy exists in the library; the second attempt is a no-op that leaves the "Saved" state unchanged.

## 10. Non-Functional Requirements

- **NFR-1** — Performance — A saved article opens to first readable content in < 500ms p95 with no network.
- **NFR-2** — Storage — The offline library uses no more than 500MB before the reader is prompted to clear space.
- **NFR-3** — Privacy — Saved content is readable only while the reader's account session is valid.

## 11. Analytics & Tracking Events

- **AE-1** — `article_saved_offline` — fires when a save completes — props: `article_id`, `source_screen`, `variant` — feeds: metric "weekly active subscribers who save ≥1 article", and which entry points drive saving.
- **AE-2** — `offline_article_opened` — fires when a saved article is opened with no connection — props: `article_id`, `time_since_save`, `variant` — feeds: the question "do readers actually consume saved content offline", and drop-off between saving and reading.
- **AE-3** — `offline_save_failed` — fires when a save attempt does not complete — props: `article_id`, `reason` (`no_connection` \| `storage_full` \| `not_entitled` \| `content_unavailable`), `variant` — feeds: metric "save attempts that fail", and which edge case dominates.

**Where the numbers are read:** the existing Reader Reliability dashboard gains an Offline panel — **read by:** Priya, weekly through launch, then monthly.

## 12. Acceptance Criteria

**FR-1 — Save for offline**
- **AC-FR-1.1** — Given an entitled reader viewing an article online, When they tap "Save for offline", Then the article appears in the Offline library and the action shows a "Saved" state.
- **AC-FR-1.2** — Given a free reader viewing an article, When they tap the save action, Then the subscribe screen opens and no article is saved.

**FR-2 — Remove saved article**
- **AC-FR-2.1** — Given a saved article, When the reader removes it, Then it no longer appears in the Offline library and its offline copy is no longer openable.

**FR-3 — Save state indicator**
- **AC-FR-3.1** — Given an article already saved, When the reader opens it, Then a "Saved" state is shown in place of the save action.

**FR-4 — Offline library**
- **AC-FR-4.1** — Given three saved articles, When the reader opens the Offline library, Then all three are listed with the most recently saved first.
- **AC-FR-4.2** — Given a saved article, When it is removed from the library, Then the list updates without the reader leaving the screen.

**FR-5 — Open offline**
- **AC-FR-5.1** — Given a saved article and no network connection, When the reader opens it from the Offline library, Then the full article text and images render with no error screen.

**FR-6 — Storage limit notice**
- **AC-FR-6.1** — Given the offline library is within 10% of the 500MB cap, When the reader saves another article, Then they are told space is running low and offered the option to remove saved articles.

**EC-1 — Save with no connection**
- **AC-EC-1.1** — If the reader taps save while offline, then the system shall leave the article unsaved, keep the save action available, and state that a connection is required.

**EC-2 — Saved article changed upstream**
- **AC-EC-2.1** — Given a saved article, When the reader opens it, Then the date it was saved is shown.
- **AC-EC-2.2** — Given a saved article whose published version has changed, When the reader opens it with a connection, Then the newer version replaces the saved copy.
- **AC-EC-2.3** — Given a saved article that has been unpublished, When the reader opens it, Then it still renders and states it is no longer available online.

**EC-3 — Out of space**
- **AC-EC-3.1** — If the device runs out of space during a save, then the system shall leave no entry in the Offline library and tell the reader space ran out.

**EC-4 — Empty library**
- **AC-EC-4.1** — Given a reader with no saved articles, When they open the Offline library, Then it explains how to save an article.

**EC-5 — Session or entitlement ends**
- **AC-EC-5.1** — If the reader's session ends or their subscription lapses, then the system shall make saved articles unreadable and prompt them to sign in or resubscribe.
- **AC-EC-5.2** — Given saved articles locked by a lapsed subscription, When entitlement is restored, Then the same articles are readable again without re-saving.

**EC-6 — Duplicate save**
- **AC-EC-6.1** — Given an article already saved, When save is triggered again, Then the library still contains exactly one copy and the "Saved" state is unchanged.

**NFR-1 — Performance**
- **AC-NFR-1.1** — When a saved article is opened offline, the system shall display first readable content within 500ms at the 95th percentile.

**NFR-2 — Storage**
- **AC-NFR-2.1** — While the offline library is at the 500MB cap, the system shall refuse further saves and tell the reader to clear space.

**NFR-3 — Privacy**
- **AC-NFR-3.1** — While no valid account session exists, the system shall keep saved content unreadable.

## 13. Rollout & Migration

- **Flag / toggle:** Offline reading — **default:** off — **who gets it first:** internal staff accounts.
- **Rollout sequence:** internal → 5% of subscribers → 50% → 100%, advancing only while the failed-save
  rate (`AE-3`) stays under 1% and crash-free sessions stay at or above the current baseline.
- **Kill switch:** With the flag off, the Offline library and save action disappear and online reading
  is unaffected. Saved copies on device are retained, not deleted, and reappear if the flag returns.
- **Existing users / data:** Nothing to migrate or backfill. Existing bookmarks are untouched.
- **Old path:** The online reader is unchanged and nothing is deprecated by this work.

## 14. Delivery Phases

- **Phase 1 — Save & store:** covers FR-1, FR-2, EC-1, EC-3, EC-5, EC-6, NFR-2, NFR-3, AE-1, AE-3 · done when AC-FR-1.\*, AC-FR-2.\*, AC-EC-1.\*, AC-EC-3.\*, AC-EC-5.\*, AC-EC-6.\*, AC-NFR-2.\*, AC-NFR-3.\* pass and AE-1, AE-3 are firing · depends on: none
- **Phase 2 — Offline reading:** covers FR-4, FR-5, EC-2, EC-4, NFR-1, AE-2 · done when AC-FR-4.\*, AC-FR-5.\*, AC-EC-2.\*, AC-EC-4.\*, AC-NFR-1.\* pass and AE-2 is firing · depends on: Phase 1
- **Phase 3 — Polish:** covers FR-3, FR-6 · done when AC-FR-3.\*, AC-FR-6.\* pass · depends on: Phase 2

## 15. Risks, Assumptions, Dependencies, Open Questions

- **Risk:** Readers expect saved articles to survive a reinstall and lose them → **Mitigation:** the
  library states that saved copies live on this device only; `EC-4` copy sets the expectation early.
- **Risk:** Saving becomes a paywall workaround (save-then-cancel) → **Mitigation:** `EC-5` locks
  content when entitlement lapses.
- **Assumption:** The existing article content service can return a complete renderable payload in one
  request.
- **Dependency:** Account/entitlement service, to gate saving to subscribers.
- **Open question:** What must happen to a saved copy when an article is taken down for legal reasons,
  as distinct from ordinary unpublishing in `EC-2` — purge on next launch, or leave readable? —
  **Owner:** Legal — **Needed by:** before Phase 2 ships.
- **Open question:** Do offline saves count against the metered article allowance for metered
  subscribers? — **Owner:** Growth — **Needed by:** before Phase 1 ships.

## 16. References

- Design (Figma): `https://www.figma.com/design/9Kd2pQ/Offline-Reading?node-id=412-1908` (Offline library + save states)
- Ticket: `https://linear.app/acme-news/issue/NEWS-1841`
- Related spec: `SPEC-reader-error-recovery.md`

## 18. Revision History

| Date | Author | Change |
|---|---|---|
| 2026-06-16 | Priya Nair | Initial draft: FR-1..FR-6, NFR-1..NFR-3, AE-1..AE-2. |
| 2026-08-14 | Priya Nair | Added EC-1..EC-6 and §13 rollout after Eng review; added AE-3 and the failed-save metric; added §6 permissions. Status → In Review. |
