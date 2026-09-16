# E2E and component-test tooling

**Currency stamp: 2026-09-06.** Parent §12 and §13 own the principles — few journeys, wait for a signal, never sleep. This file is the per-tool mechanics, because the three most common tools spell the same idea differently and the snippets are *not* portable.

---

## The waiting model, per tool

| | Retries automatically | The async escape hatch | Never |
|---|---|---|---|
| **Playwright** | locators auto-wait; `expect()` polls | `expect.poll`, `waitForResponse` | `page.waitForTimeout()` |
| **Testing Library** | **nothing** — `getBy*` is synchronous | `await findBy*`, `waitFor` | `setTimeout` in the test |
| **Cypress** | queries retry; the whole chain re-runs | `cy.intercept()` + alias + `cy.wait('@alias')` | `cy.wait(500)` |

This table is the single most valuable thing in the file. Copying a Playwright `getByRole(...).click()` into a React Testing Library test produces the most common RTL bug there is, because the name is identical and the behaviour is not.

## Playwright

- **Locators auto-wait for actionability** and web-first assertions poll until timeout, which is why a fixed sleep is never needed. The docs are explicit: tests that wait for time are inherently flaky.
- **Subscribe before you act**: `const resp = page.waitForResponse(url)` *then* click *then* `await resp`. Registering after the action misses the event and hangs.
- `page.route()` to stub third parties; `storageState` to reuse auth without re-logging in (watch the order-coupling warning in parent §14).
- Traces on first retry (`trace: 'on-first-retry'`) are the diagnostic that makes parent §15's "retries diagnose, they don't repair" actionable.

## Testing Library (React/Vue/Svelte/Angular)

- **Query priority, in order:** `getByRole` (with `name`) → `getByLabelText` → `getByPlaceholderText` → `getByText` → `getByDisplayValue` → … → `getByTestId` **last**. The docs are explicit that a test id is for when nothing user-facing can identify the element. Role queries also assert your accessibility tree for free.
- **`getBy*` throws immediately, `queryBy*` returns null, `findBy*` returns a Promise.** Use `getBy*` for what's already on screen, `await findBy*` after anything async, and `queryBy*` **only** to assert absence (`expect(queryByRole(...)).not.toBeInTheDocument()`).
- `userEvent` over `fireEvent` — it models real interaction sequences (focus, keydown, input) rather than dispatching one synthetic event.
- Wrap nothing in `act()` by hand if you're using `userEvent` and `findBy*`; a manual `act()` is usually a sign you're fighting the async model.

## Cypress

- **Retry-ability is chain-scoped**: queries link up and the whole chain retries together. **Action commands execute once** and do not retry, and **`.then()` is an explicit retry boundary** — assertions after a `.then()` don't get the earlier chain's protection.
- **The sanctioned replacement for a fixed wait** is `cy.intercept('POST', '/api/save').as('save')`, act, then `cy.wait('@save')`. This is deterministic; `cy.wait(500)` is a guess.
- `cy.session()` for cached login state; `cy.task()` for seeding data outside the browser (parent §14).

## Mobile

- **Espresso** has built-in idling synchronization; register an `IdlingResource` for your own async work rather than sleeping. `ViewMatchers`/`ViewActions`/`ViewAssertions` are the role/act/assert triple.
- **XCUITest** `waitForExistence(timeout:)` is the wait-for-signal primitive; accessibility identifiers are the stable locator, and they are the mobile equivalent of preferring role over CSS.
