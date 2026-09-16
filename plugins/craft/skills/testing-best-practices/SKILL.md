---
name: testing-best-practices
description: "Baseline for writing test cases — load whenever writing, editing, fixing or reviewing tests in any language or stack (unit, integration, contract, e2e/UI, snapshot), and the moment you author or change a test, set up fixtures, or chase a failing/flaky/slow test. Covers behavior-over-implementation, choosing the level (pyramid/trophy/honeycomb), test doubles and never mocking types you don't own, one-behavior spec names, AAA without comments, determinism (FIRST), proving a test can fail, mutation and property-based testing, e2e locator priority and wait-for-signal-never-sleep, and flaky-test triage. Triggers on any Edit/Write of a test file (*.test.*, *_test.*, *_spec.*, tests/**) or: 'write/add tests', unit/integration/e2e test, coverage, flaky, mock, stub, fixture, TDD, Jest, Vitest, pytest, JUnit, RSpec, go test, XCTest, Playwright, Cypress. Skip for production code, endpoint and schema design, CI/CD deploy, load/perf, and statistical or A/B tests — but DO load for tests of stateful UI components."
---

# Testing Best Practices

A polyglot test reviewer, teacher, and author. Every principle here is language- and framework-independent; examples are pseudocode. **Always render Bad/Good pairs in the user's actual stack** — their test runner (Jest/Vitest, pytest, JUnit, RSpec, `go test`, XCTest), their assertion library, their e2e tool (Playwright/Cypress/Espresso/XCUITest). You **review** existing tests, **teach** these principles on demand, and **author** new tests and harnesses — every point carries a concrete Bad/Good pair plus one line of *why*.

**This skill owns the test suite itself** — what to test, at which level, how to shape a test, and how to keep the suite fast and trustworthy over time. It does **not** re-teach general code quality: a test is production code, so naming, DRY, guard clauses, dead-code removal, and scope discipline come from `coding-best-practices` — assume it's active and apply it *to the test code too*. Designing the *code under test* to be testable (pure core / thin impure shell, injectable effects) is `coding-best-practices` §12 — this skill picks up where that leaves off. Backend integration specifics (real DB, contract-testing service boundaries, testing failure paths) deepen `backend-best-practices` §22; the shape of the data those tests run against — and whether an invariant should be a database constraint rather than an assertion — is `database-best-practices`; UI state lives in `ui-state-best-practices`. **Standing up the harness itself** — installing a runner, wiring DI seams, adding a CI stage — is `testing-setup` where it applies (currently Android-only): it decides *what to install*, this skill decides *what the tests it scaffolds must look like*. When both are active, let it do the wiring and apply every principle here to every test it produces. When an issue is really a general-quality or design issue, name it and defer.

## Skill chaining

These compose — invoke the ones that apply with the Skill tool rather than re-teaching their material here.

| Invoke | When | It owns |
|---|---|---|
| `coding-best-practices` | always, on any code work — **including the test code itself** | naming, structure, error handling, dead code, scope discipline; and §12, designing the code under test to be testable |
| `backend-best-practices` | testing an endpoint, consumer, job or datastore integration | what a real-infra integration test must exercise: transactions, idempotency, retries, failure paths |
| `database-best-practices` | the tests run against a schema | the shape of the test data, and whether an invariant belongs as a database constraint rather than an assertion |
| `ui-state-best-practices` | testing stateful UI components | state shape and data flow in the component under test |
| `opinionated-frontend-architecture` | testing state shared across screens — a store, sign-out, session teardown | *where* a fact lives across the app, and session lifetime |
| `testing-setup` | standing up a harness from nothing (Android) | what to install and how to wire it — this skill still governs what the tests it scaffolds look like |

Chain in both directions: when one of those invoked you to write a test, write it and hand the domain question back.

**One reply, one budget.** When several of these load together they share a *single* 5–7 issue cap, not one each — pick the highest-impact issues across the whole set, and never restate a point a sibling already made.

## The objective: catch real regressions, run fast, never lie

A test suite exists to let you change code with confidence. It earns that only if it **fails when behavior breaks, passes when behavior is preserved, and does both fast enough that people actually run it.** A suite that breaks on every refactor trains people to delete tests; a suite that passes while the feature is broken is worse than none; a suite that takes 40 minutes gets skipped. When principles conflict, resolve in this order:

1. **Faithful** — the test fails for a real behavior change and *only* for a real behavior change. A test coupled to implementation (asserting internal calls, private fields, exact log strings) breaks on refactors that changed nothing a user sees — false alarms that erode trust. A test that can't fail, or asserts nothing meaningful, gives false comfort.
2. **Fast & deterministic** — same input, same result, every run, quickly. Flakiness and slowness are not annoyances; they are the two failure modes that kill a suite's value outright.
3. **Readable** — the next person reads the test as the spec for the behavior: what's set up, what's exercised, what's expected, at a glance.

When **reviewing**, push tests toward this and skip nitpicks; lead with the highest-impact problems (tests that can't catch bugs, flaky tests, tests coupled to implementation) before style. When **writing**, produce this version directly.

## How to operate

**Establish the testing context first — always.** Before reviewing or writing, pin these down and let them shape every suggestion:

- **Language, test runner & assertion style** — render every example in the project's actual framework and idioms (`describe/it` + `expect`, `pytest` + `assert`, JUnit + AssertJ, table-driven `go test`, RSpec `describe/context/it`). Match what's already there.
- **The layer you're at** — unit, integration, contract, or e2e. The right double, the right thing to assert, and the right speed budget all change by layer. Don't apply unit-test instincts to an e2e test or vice versa.
- **The system's architecture & risk shape** — a modular library, a microservice mesh, a frontend app, a mobile app. This decides the test *shape* (below) and where the real risk lives.
- **The project's existing testing posture** — its conventions, coverage bar, CI setup, and how it fakes IO. Match it; don't impose a foreign structure. If the project has no tests and the user didn't ask for a suite, design *for* testability and say so — don't silently add one (`coding-best-practices` §12).

**When reviewing:** read the tests → flag the highest-impact problems first (can't-catch-bugs, flaky, implementation-coupled, slow) → for each, a Bad snippet and a Good snippet in the user's stack plus one line of *why* → limit to 5–7 issues unless asked for exhaustive feedback.

**When teaching:** name the principle → one-sentence explanation → Bad/Good pair → *why* the Good version wins.

**When authoring:** settle the layer and what behavior you're pinning down first, then write the test as a readable spec. Watch the model's pull toward testing the happy path only and toward over-mocking — enumerate the edges (`coding-best-practices` §9) and reach for real objects before doubles.

**Install via the project's CLI, then run what you wrote.** New test dependencies go in with the ecosystem's CLI (`bun add -d`, `uv add --dev`, `go get`, `flutter pub add --dev`) — never by typing a version into a manifest or lockfile. Then execute the test with the project's own runner and quote the result: the failing assertion when you prove it red (§9), the pass count when it's green. **A test you did not run is unverified, not written** — and asserting what it "would" do is exactly the habit §9 exists to prevent.

**Output format** for each issue or principle:

```
### [Principle]
[one-sentence explanation]
**Bad:**  [test that violates it]
**Good:** [test that follows it]
[why the Good version wins — 1-2 sentences]
```

**Voice** — the shared rules (no section-number citations in your output, never fabricate the user's code, match their energy) come from `coding-best-practices`. One addition here: **any test code you write is still production code** — no `// --- section ---` banners, no narration; let the test name and structure carry the meaning.

---

## Part 1 — Strategy: what to test, and where

### 1. Test observable behavior, not implementation
This is the master principle; most bad tests violate it. Assert what the unit *does* that someone outside can observe — its return value, the state it changes, the effect it causes — not *how* it does it internally. A test bound to internal method calls, private fields, or call order re-breaks on every refactor that preserved behavior, so it punishes exactly the cleanup you want to encourage.

**Bad:** `expect(orderService.repo.save).toHaveBeenCalledWith(order)` — asserts an internal collaborator was called; passes even if the saved data is wrong, fails the moment you rename or reshape the call.
**Good:** call `placeOrder(...)`, then assert the *effect*: `expect(await repo.findById(id)).toEqual({ ...order, status: "placed" })` — verifies the outcome a user cares about, survives any refactor that keeps that outcome.
- **Prefer state/effect verification over behavior verification.** Checking "the DB now holds this row" or "the function returned this value" beats checking "the mock was called" — the former lets you change the implementation freely (ties to §3).
- **A test you never have to touch during a pure refactor is a good test.** If refactoring internals turns your suite red without any behavior change, the tests are testing the wrong thing.
- This is `coding-best-practices` §12 surfaced as its own discipline: use the real thing for your own domain code, and substitute only at boundaries you don't control — through an adapter you do own (§3).

### 2. Choose the level: the pyramid (and when to reshape it)
Test each behavior at the **lowest, cheapest level that can actually catch its failure**, and write many fast low-level tests, fewer slow high-level ones. The classic **pyramid** — a wide base of unit tests, fewer integration tests, a thin cap of e2e — is the right default because lower tests are faster, more numerous, and pinpoint failures precisely. Don't test the same logic at three levels; push each check as low as it can meaningfully live.

**Bad:** a full browser e2e test to check that a discount is 10% off — slow, flaky, and it can't tell you *which* function got the math wrong.
**Good:** a unit test on the pricing function for the 10% math; one e2e test that the checkout *journey* works end-to-end. Each failure points at one place.
- **Reshape the pyramid to where your risk lives** — it's a heuristic, not a law. Modern frontends often fit the **testing trophy** (thin unit layer, wide *integration* layer, thin e2e, static analysis/types underneath) because a component's value is in how its pieces integrate. Microservices fit the **testing honeycomb** (Spotify): a fat middle of *integration* tests that exercise this service through its real HTTP/queue surface against **simulated** neighbours, a thin band of implementation-detail unit tests below, and as close to zero *integrated* tests above. That distinction carries the weight: an **integration** test verifies your service's interaction points against stand-ins you control; an **integrated** test passes or fails based on whether *another team's running system* is healthy, which is a scam rather than coverage. "Fat integration middle" never means standing up three real neighbouring services.
- **The deciding question is "where do this system's real bugs occur?"** Put the bulk of tests there. If your integration tests are genuinely fast and reliable, you need fewer unit tests beneath them (Fowler's own caveat).
- **Static analysis and types are the free foundation** — a compiler, type checker, and linter catch a class of bugs before any test runs; lean on them so tests can focus on behavior.

### 3. Use the right test double — and never mock a type you don't own
A *test double* stands in for a real dependency. The five kinds (Meszaros/Fowler) are not interchangeable: **dummy** (a placeholder never used, just fills a parameter), **stub** (returns canned answers to queries), **fake** (a real but shortcut implementation, e.g. an in-memory repository), **spy** (a stub that also records how it was called), **mock** (pre-programmed with expectations that are *verified* — "was I called exactly like this?"). Reach for the lightest one that does the job, and **use a real object whenever it's practical.**

**Bad:** `const repo = mock(); when(repo.find).thenReturn(user); ...; verify(repo.find).calledOnce()` — a strict mock asserting call mechanics, coupling the test to how the code fetches (ties to §1).
**Good:** `const repo = new InMemoryUserRepo([user])` — a **fake** you can query for real effects; the test asserts outcomes and doesn't care how many times `find` ran.
- **Substitute at true external boundaries — but substitute your own adapter, never the vendor's types.** Effects you don't control (a payment gateway, a third-party API, the clock, randomness, the network) must be replaced in tests. Do it by wrapping the SDK in the narrow interface your domain actually needs and faking *that*. A hand-rolled double of someone else's client encodes **your guess** at their semantics: it stays green through a breaking upgrade, and its assertions are unverifiable because no real call ever confirms them. Pin the adapter itself with one integration test against the real thing (§11). This is the canonical "don't mock what you don't own," and it points the opposite way from the phrase people misremember.
- **Use the real object for code you own.** Your own domain services, value objects and pure functions get instantiated, not doubled. A test drowning in mocks just asserts that the mocks were called; it passes when the logic is wrong and breaks on every refactor.
- **Prefer fakes to strict mocks.** A well-written fake (in-memory DB, in-memory queue) gives classicist-style tests that assert real effects while staying fast — the modern synthesis. Reserve strict/behavior-verifying mocks for the narrow cases where the *interaction itself* is the contract (e.g. "we must send exactly one email") or where state verification is genuinely impractical.
- **Heavy reliance on `spyOn`/monkey-patching is a design smell** — it usually means the dependency should be passed in explicitly (`coding-best-practices` §12), not reached for globally.
- **If you fake a boundary you own on both sides, contract-test it** so the fake and the real thing can't drift (§11).

### 4. Cover the risk, not the line count
Coverage tells you what code *ran* during tests, not whether it's *correct* — 100% coverage with weak assertions catches nothing. Use coverage to find blind spots (untested branches, error paths), never as the goal. The real target is: every behavior that matters, and every reachable edge, has a test that fails when it breaks.

**Bad:** a test that calls `process(order)` and asserts nothing (or only `expect(result).toBeDefined()`) — 100% line coverage, zero behavior verified.
**Good:** tests that assert the actual computed total, the empty-cart case, the over-limit rejection, and the payment-failure path — coverage follows from testing the behaviors, not the reverse.
- **Enumerate edges before you ship** (`coding-best-practices` §9): empty/one/many, null/absent, zero/negative/overflow, boundary values, and the *failure paths* — the timeout, the rejection, the concurrent update. The happy path rarely regresses silently; the edges do.
- **Test the failure and error paths explicitly** — the `catch`, the validation rejection, the retry-exhausted case. Bugs hide where the happy-path demo never goes.
- **Don't chase coverage on trivial or untestable code** (§18) — a getter or a framework glue line doesn't need a test just to color a line green.
- **When you need to know whether the assertions are real, run mutation testing — not more coverage.** A mutation tool flips operators and return values and reports which mutants your suite kills; a *surviving* mutant is a line you execute but never actually check. Coverage cannot measure assertion strength and mutation score can — an 88%-branch-coverage class can sit at 41% mutation coverage. Run it on the risky module, not the whole repo, in changed-files mode in CI (`stryker` JS/TS, `pitest` Java/Kotlin, `mutmut`/`cosmic-ray` Python, `go-mutesting`), and read surviving mutants as a to-do list of missing cases. 100% is not the target — some mutants can't change observable behavior and are unkillable by definition.
- **When the behavior has an invariant, assert the invariant over generated input.** Round-trips (`parse(render(x)) == x`), commutativity, monotonicity, "never negative", "output is a permutation of the input" — a property test explores thousands of cases you wouldn't enumerate and shrinks any failure to the smallest input that breaks it (`fast-check`, Hypothesis, `jqwik`, `gopter`, `rapid`). Paste that shrunk counterexample back in as a fixed example test so the regression is pinned forever.

---

## Part 2 — Anatomy of a good test

### 5. One behavior per test, named as a spec
A test verifies one logical behavior and its name states that behavior, so a failure name alone tells you what broke without opening the file. Cramming several behaviors into one test means the first failed assertion hides the rest, and the name can't describe what it checks.

**Bad:** `test("user works", () => { /* creates, updates, deletes, and checks permissions */ })` — one failure and you don't know which behavior; the name says nothing.
**Good:** `test("rejects signup when email is already registered", ...)` — one behavior, and the name reads as a requirement. (Or `describe("signup") { it("rejects a duplicate email") }`.)
- **Name the behavior and condition, not the method.** `test_calculateTax` is a label; `test("applies zero tax to exempt items")` is a spec. Pick a convention and hold it: `should_<expected>_when_<condition>`, `given/when/then`, or a plain sentence.
- **"One behavior" ≠ "one physical assert."** Several asserts that together pin down *one* outcome (status is 200 *and* body has the id *and* the row exists) are one logical assertion — fine. Asserting three *unrelated* behaviors is not.

### 6. Arrange–Act–Assert: one clear shape, no logic in tests
Structure every test as **Arrange** (set up inputs and world), **Act** (invoke the one thing under test), **Assert** (check the outcome) — separated by a blank line, **never by `// Arrange` / `// Act` / `// Assert` comments and never by a test docstring**. If the three phases aren't obvious without labels, the test is doing too much (§5) or the setup needs a named builder (§10); the test's name is its only prose. A test with branches, loops, or its own calculations has become code that itself needs testing, and can hide bugs behind conditionals that never run.

**Bad:** `for (const c of cases) { if (c.premium) expect(price(c)).toBe(c.x); else expect(price(c)).toBe(c.y) } ` — control flow in the test; a wrong branch can silently skip the real check.
**Good:** a table-driven test where the *data* varies but the body is a flat Arrange-Act-Assert with no branching (`it.each(cases)` / parameterized / table-driven `for` with no `if`), so every row runs the same straight-line check.
- **No conditionals or non-trivial computation in a test.** If a test needs an `if`, split it into two tests. If it recomputes the expected value with the same logic as the code, it will share the same bug — assert against a *literal* expected value instead.
- **Keep Arrange visible and honest.** Hidden setup in far-away fixtures (the "Mystery Guest") makes a test unreadable and coupled to global state; prefer local, explicit setup or a named builder (§10).

### 7. Deterministic and isolated (FIRST)
Good tests are **F**ast, **I**solated, **R**epeatable, **S**elf-validating, **T**imely (Ottinger & Schuchert). **Timely** means written just before the code they cover, so the test shapes the design rather than ratifying it (§9) — it's the only letter that makes a design claim. The two that break suites are isolation and repeatability: a test must not depend on other tests, execution order, or shared mutable state, and must give the same result every run. Non-determinism comes from uncontrolled inputs — the clock, randomness, network, real time delays, ambient DB state, parallel workers touching the same data.

**Bad:** `expect(createUser().createdAt).toBe(Date.now())` — depends on the wall clock; `test A` seeds a row `test B` reads — order-coupled and parallel-unsafe.
**Good:** inject a fixed clock (`createUser({ now: FIXED })`) and give each test its own isolated data (fresh fixture / transaction rollback / unique keys) so order and parallelism can't matter.
- **Control every non-deterministic input** — freeze time, seed or stub randomness, fake the network, avoid real `sleep`. This is why `coding-best-practices` §12 pushes effects to the edges: injectable effects are what make a test repeatable.
- **Each test sets up and tears down its own world** — no reliance on a previous test's side effects, no leftover state for the next. Self-contained tests can run in any order and in parallel.
- **Self-validating** — the test decides pass/fail via assertions; never "print it and eyeball the output." A human in the loop can't run in CI.

### 8. Assert precisely — meaningful, and not too much
The assertion is the point of the test; it must be specific enough to catch the bug and loose enough to survive irrelevant change. Too weak (`toBeDefined`, `not.toThrow`) catches nothing; too strict (asserting an entire serialized object including timestamps and ids) breaks on incidental change and buries the one field that matters.

**Bad:** `expect(res.status).toBe(200)` *only* — the endpoint could return `200` with a wrong or empty body and the test is happy.
**Good:** assert the status *and* the fields that define correct behavior: `expect(res.status).toBe(200); expect(res.body.items).toHaveLength(2); expect(res.body.items[0].name).toBe("Ada")`.
- **Assert the meaningful thing, not everything.** Pin the fields the behavior is about; don't snapshot volatile data (timestamps, generated ids, ordering that isn't guaranteed) — those make faithful tests fail for fake reasons.
- **Use expressive matchers** for readable failures — `toContain`, `toMatchObject`, `assertThat(x).hasSize(2)` produce a diagnostic message; a bare `assert(a == b)` on two big objects prints a wall of text.
- **Snapshot tests earn their keep only for stable, reviewed output.** A giant auto-approved snapshot no one reads is coverage theater — it goes green on `--update` and never catches a real regression.

### 9. A test must fail for the right reason — see it red first
A test that has never failed is unproven: it might be asserting nothing, testing the wrong thing, or short-circuited by a setup bug. Before trusting a test, watch it fail when the behavior is wrong (write it first, or temporarily break the code) and confirm the failure message actually names the problem.

**Bad:** write the test after the code, it passes immediately, ship it — you never learned whether it *can* fail. (A misspelled async assertion that's never awaited "passes" forever.)
**Good:** red → green: see the test fail with a clear message against the unfixed/wrong code, then make it pass. Now you know it guards the behavior. This is the core of TDD, but it applies even when you test after.
- **Check the failure message, not just that it failed** — it should tell the next engineer *what* broke and *what was expected*. A cryptic failure costs debugging time exactly when someone's already stuck.
- **A "lock-in" test after a bug fix must fail on the old code and pass on the new** — that's what proves the regression can't silently return.
- **Prove it can fail, mechanically.** Invert the expected value once, confirm it goes red with a message that names the real problem, then restore it. For async code also assert the count — `expect.assertions(n)`, or `pytest.raises` as the assertion itself — so a callback that never ran fails instead of passing. Every `expect` on a promise is `await`ed or returned, and the runner is configured to fail on unhandled rejections. A floating promise, a missing `await` on `expect(...).rejects`, or an assertion inside an un-awaited `.then()` produces a test that is **permanently green and structurally incapable of failing** — the single most common way a suite silently stops working.
- **A failing test is evidence about the code, not about the test.** When one goes red, the default hypothesis is that the production code is wrong. Change the test only when you can state in one line what behavior legitimately changed and why the old assertion was wrong. **Never** weaken an assertion, widen an expected value to match observed output, add `.skip`/`@Ignore`/`t.Skip`, or delete a test in order to get to green — that converts a caught regression into a shipped one. §10's "delete tests that no longer earn their place" means tests for behavior that no longer exists; it never means a test that is currently failing.

### 10. Keep tests readable — real objects and builders over Mystery Guests
Test code is read far more than written; optimize for the reader diagnosing a 3am failure. Some duplication in tests is *fine* and often clearer than a clever helper — but repeated, noisy setup wants a named builder/factory that spells out only what matters for this test. Beware over-abstracting tests into a framework of their own.

**Bad:** every test builds a user with 12 fields inline (noise drowns the one relevant field), or a shared `beforeEach` sets up a tangle no single test's meaning is clear from (Mystery Guest).
**Good:** `aUser().withEmail("dup@x.com").build()` — a builder with sensible defaults; the test names *only* the field it's about, and its intent is obvious in isolation.
- **Favor obviousness over DRY in tests.** A little copy-paste that keeps each test self-explanatory beats a shared abstraction that makes you jump around to understand one case (`coding-best-practices` DRY still applies — but the readability bar for tests is "understandable standalone").
- **No test-only branches in production code.** `if (isTest) ...` couples shipping code to the suite and means you're no longer testing what you ship; inject the seam instead.
- **Delete or fix tests that no longer earn their place** — a commented-out, `.skip`-ped, or always-passing test is dead code that lies about your safety net (`coding-best-practices` dead code).

---

## Part 3 — Integration & end-to-end

### 11. Integration tests hit real boundaries
Integration tests exist to catch the bugs unit tests can't: the actual SQL, the schema constraint, the serialization, the transaction, the wiring between components. A "integration" test that mocks the database is a unit test in disguise — it asserts your mocks, not your behavior. Run the risky integrations against something real.

**Bad:** test the repository by mocking the DB driver and asserting the query string — passes even when the SQL is malformed, the constraint is wrong, or the migration never applied.
**Good:** run against a real ephemeral database (testcontainers / an in-process instance / a disposable schema), insert and query for real, and assert the *observed rows* — catches the schema/SQL/transaction bugs mocks can't (`backend-best-practices` §22).
- **Use real infra for components you own** (your DB, your cache); substitute third parties you don't — through your own adapter over their SDK, never a double of their types (§3).
- **Contract-test service boundaries** — for consumer/provider pairs, a consumer-driven contract (e.g. Pact) verifies both sides against an agreed schema so a breaking change is caught in CI, not by a pager. Same idea keeps a fake (§3) honest against the real implementation.
- **Test the boundary's failure modes** — the timeout, the duplicate delivery, the rollback, the concurrent update (`backend-best-practices` §22).

### 12. End-to-end tests cover a few critical journeys — from the user's view
E2E tests are the slowest, flakiest, most expensive tests you own, so spend them only on the handful of journeys where a break is catastrophic (sign up → pay → receive), verified the way a user experiences them. They answer "is the whole system wired together?", not "is this function correct?" — that's what the layers below are for.

**Bad:** 200 e2e tests covering every field-validation permutation through the real UI — a slow, flaky suite that takes an hour and gets ignored; each failure could be any of a dozen layers.
**Good:** a small set of e2e tests for the money-making journeys, with field-validation edges pushed down to fast component/unit tests. E2E confirms integration; lower layers confirm logic.
- **Test user-visible outcomes, not internals** — "the confirmation page shows the order number", not "the `orders` table got a row" (that's an integration test's job).
- **Keep the count small and the value high.** Every e2e test is a standing maintenance and flakiness cost; add one only when a real end-to-end break would be expensive to miss.

### 13. E2E determinism: wait for a signal, never sleep
The number-one cause of flaky UI tests is timing — the test acts before the app is ready. **Never** use a fixed sleep (`waitForTimeout(500)`): it's either too short (flaky) or too long (slow), and it encodes a guess about machine speed that breaks on a loaded CI runner. Wait for the specific condition you actually need, and assert on the *outcome*, not just that an element appeared.

**Bad:** `await click("#submit"); await sleep(500); expect(await text(".toast")).toBe("Saved")` — races the async save; passes on a fast laptop, fails on a slow CI box.
**Good (Playwright):** `await page.getByRole("button", {name:"Submit"}).click(); await expect(page.getByRole("status")).toHaveText("Saved")` — a web-first assertion that *retries* until the real outcome appears, deterministic without a magic number.
- **The waiting model differs per tool — don't port this snippet blindly.** In **Playwright** locators auto-wait and `expect` polls. In **Testing Library** `getBy*` is **synchronous and does not retry**, so after an async action you need `await screen.findByRole(...)` (or `waitFor`); `queryBy*` exists only for asserting *absence*. In **Cypress** only queries retry and the whole chain re-runs together — action commands execute once, `.then()` is an explicit retry boundary, and the sanctioned replacement for `cy.wait(500)` is `cy.intercept()` + alias + `cy.wait('@alias')`. Copying Playwright's `getByRole(...).click()` into a React Testing Library test is the single most common cross-tool mistake.
- **Auto-waiting isn't enough on its own** — a runner waits for an element to be actionable, but it doesn't know your business logic finished. After a click that triggers an async update, assert the *data* changed (the row's new text), not just that a container is visible.
- **Subscribe before you act** when waiting on a request: set up the wait (`const resp = page.waitForResponse(url)`), *then* trigger it, *then* await — registering after the action misses it and hangs.
- **Locate the way a user identifies the element, in this order:** role + accessible name, then label, then visible text — and only when none of those can identify it, an explicit `data-testid`. These are not interchangeable alternatives: role-based locators fail when you break the accessibility tree, which is a bug worth catching, and a test id never does. Never CSS/XPath tied to markup structure or generated class names.
- **Make the environment deterministic** — fixed viewport/browser, disabled animations, frozen time, mocked/seeded third parties, and a known data state; "passes headed on my machine, fails headless in CI" is usually viewport, timing, or data drift.

### 14. Own your test data: seed it, isolate it, reset it
Shared, accumulating test data is a slow-motion flakiness generator — one test's leftovers change another's result, and order suddenly matters. Each test (or each run) starts from a known state it created and cleans up after, so tests can run in any order and in parallel without colliding.

**Bad:** tests run against a shared staging DB that anyone can mutate; `test B` assumes the 3 users `test A` created still exist — green today, red when tests reorder or run in parallel.
**Good:** each test seeds exactly the data it needs into an isolated space (transaction rolled back per test, a fresh schema/namespace, or unique keys per test) and asserts only on that — no dependence on ambient state.
- **Prefer per-test isolation** (transaction rollback, ephemeral container, unique tenant/prefix) over a shared fixture everyone mutates.
- **Reset before, not (only) after** — a crashed test leaves garbage; setting up clean state at the *start* makes the suite robust to previous failures.
- **Beware shared login/session state** — reusing one authenticated session across e2e tests speeds them up but re-introduces order coupling if a test mutates that account; isolate where it matters.

---

## Part 4 — Sustaining the suite

### 15. Kill flakiness; never normalize it
A flaky test — one that passes and fails on the same code — is worse than no test: it trains the team to ignore red CI, and real regressions then hide behind the noise. Treat every flake as a bug with a root cause, not a dice roll to re-roll. The re-run reflex is the trap.

**Bad:** the test fails intermittently, so CI is set to retry 3×; it "passes" and the merge goes through — the underlying race is still there, now invisible, and trust in the suite quietly dies.
**Good:** reproduce it (run it many times: `--repeat-each`, rerun under load), find the category — timing/async, shared state, unstable selector, resource contention, non-deterministic input — and fix *that*. Retries stay only as a diagnostic (capture a trace on first retry), never as the cure.
- **Diagnose by category** — most flakes are: acted-before-ready (§13), test interdependence/shared state (§14), unstable locator (§13), or an uncontrolled input like clock/random/network (§7). Each has a real fix.
- **Retries diagnose, they don't repair** — `retries: 2` with trace-on-retry gives you the evidence to fix the flake; a permanent retry policy is a decision to stop looking.
- **Quarantine the residue with accountability** — move a stubborn flake to a separate *non-blocking* job (so it still runs and you keep the signal), tagged with the suspected cause, and give it an **owner, a ticket, and a deadline**. A quarantined test protects nothing; time-box it (fix or delete within a sprint or two). Don't silently `.skip` it into oblivion.
- **Quarantine on a measured rate, and always state the unit.** Track pass/fail per test across runs; anything failing on unchanged code more than roughly **1 run in 100** goes to the non-blocking job with an owner and a ticket. That same per-run rate is the suite-level budget — Google measures about **1.5% of all test runs** flaky across roughly **16% of tests**, which is why "a 2% flake rate" is meaningless unless you say whether you mean per run or per test.

### 16. Fast feedback — keep the loop tight
A slow suite is a skipped suite. The unit layer should run in seconds so developers run it constantly; slower integration/e2e layers run less often (pre-push, CI) but must still finish before attention wanders. Speed is a feature you protect, not an accident.

**Bad:** every test spins up the full app, a real DB, and seeds 10k rows — the "unit" suite takes 12 minutes, so nobody runs it before pushing and breakage is found late.
**Good:** true unit tests run pure logic in-memory (milliseconds each); integration tests share a fast ephemeral DB and run in parallel; the heavy e2e set is a small, separate CI stage. Each layer meets its budget.
- **Parallelize and isolate** (§14 makes this safe) — independent tests should run concurrently across workers.
- **Budget by layer** (adapt to the project): unit tests in single-digit milliseconds each, the whole unit suite in seconds-to-low-minutes; keep e2e small precisely because each run is expensive.
- **Push work down the pyramid** to reclaim speed — a behavior tested at the unit level doesn't need a slow e2e re-test (§2).

### 17. Test code is production code
The suite is a codebase you maintain forever; hold it to the same bar as shipping code. Everything in `coding-best-practices` applies **to the tests**: intent-revealing names, no duplicated-and-drifting setup, no dead/`skip`-ped tests rotting in place, small focused units, and surgical diffs. Sloppy tests decay into a suite people fear to touch and eventually delete.

**Bad:** copy-pasted 40-line setup across 30 tests, cryptic names (`test1`, `testUser2`), and five commented-out tests "we might need" — the suite is now a liability nobody trusts or edits.
**Good:** shared setup behind a named builder (§10), spec-style names (§5), dead tests deleted (version control remembers), each test small and single-purpose — the suite reads as living documentation.
- **Refactor tests too** — when the code's design changes, update the tests' structure; don't let them ossify into a museum of the old shape.
- **Apply the same review lens** — a test PR gets the same scrutiny for clarity and correctness as any other.

### 18. Know what NOT to test
Tests cost time to write and maintain; spending them on the wrong things adds drag without adding safety. Don't test code with no logic, code you don't own, or internals you can reach through the public surface — those tests are pure maintenance with no bug-catching upside.

**Bad:** a test asserting a plain getter returns the field it was set to; a test re-verifying the standard library's `sort` works; a test reaching into a private method via reflection to assert an intermediate value.
**Good:** trust the language/framework and third-party libraries (test only *your* use of them at a boundary); test private logic *through* the public API that exercises it — and if a private piece is complex enough to deserve its own test, that's a signal to extract it into its own unit (`coding-best-practices` §12).
- **Don't test the framework or the language** — assume `map`, the ORM's basic persistence, and the HTTP router work; test the behavior *you* built on top.
- **Don't test implementation details through the back door** — no reflection into privates, no asserting on internal call order (§1). If it's worth testing directly, it's worth extracting.
- **Skip trivial, logic-free code** — getters/setters, pass-through delegators, pure config. Coverage tools will flag them red; that's fine (§4).

### 19. Untested legacy code gets characterization tests first
Every principle above assumes a seam exists. When you're asked to add tests to code that has none — the most common real starting condition — you can't write a spec, because nobody knows what the spec is. So pin what the code *currently does*, bugs included, before changing anything.

**Bad:** refactor the untested function first "to make it testable", then write tests against the refactored output — that pins the refactor's bugs as if they were the requirement, and you have no way to tell what you broke.
**Good:** run the existing code, capture its actual output for a spread of realistic inputs, and assert exactly that. Then create a seam (extract the part you're changing into something you can call directly), and only then write the real spec for the new behavior.
- **Name them so nobody mistakes them for requirements** — `characterizes_current_behavior_*`. A characterization test deliberately encodes wrong behavior; if it reads like a spec, someone will defend the bug.
- **This is the one case where a failing test might mean the test is right and the code is right** — a characterization test failing after an intentional behavior change is expected. Update it deliberately and say so. That is not a licence to weaken tests generally (§9).

---

## The whole thing on one card

| # | Principle | One line |
|---|---|---|
| 1 | Behavior, not implementation | Assert observable outcomes/effects; a pure refactor shouldn't turn tests red. |
| 2 | Choose the level | Test each behavior at the lowest level that can catch it; shape the pyramid to your risk. |
| 3 | Right double, never mock what you don't own | Real objects and fakes; substitute vendors through your own adapter, not their types. |
| 4 | Cover the risk, not the lines | Coverage finds blind spots; behaviors and edges are the target, not 100%. |
| 5 | One behavior, named as a spec | Each test checks one thing; its name states the requirement. |
| 6 | Arrange-Act-Assert, no logic | Straight-line tests; no `if`/loops/recomputation in the test body. |
| 7 | Deterministic & isolated (FIRST) | Control clock/random/network; no order or shared-state coupling. |
| 8 | Assert precisely | Meaningful assertions; don't under-assert, don't snapshot volatile noise. |
| 9 | See it fail first | An unproven test may assert nothing; watch it go red for the right reason — and never weaken one to get green. |
| 10 | Readable — builders over Mystery Guests | Self-explanatory tests; some duplication beats a clever abstraction. |
| 11 | Integration hits real boundaries | Real DB/infra you own; contract-test service seams. |
| 12 | E2E: few critical journeys | Slow and precious — spend on money-making paths, user-visible outcomes. |
| 13 | Wait for a signal, never sleep | Outcome-based web-first assertions + stable locators, not fixed delays. |
| 14 | Own your test data | Seed it, isolate it, reset it — any order, in parallel, no collisions. |
| 15 | Kill flakiness | Root-cause it; retries diagnose not cure; quarantine with owner+ticket+deadline. |
| 16 | Fast feedback | Unit suite in seconds; parallelize; push work down the pyramid. |
| 17 | Test code is production code | Names, DRY-enough, no dead tests; apply coding-best-practices to the suite. |
| 18 | Know what not to test | Skip trivial/framework/third-party code and back-door internal tests. |
| 19 | Legacy gets characterization first | Pin current behavior (bugs included) before you change it; name it so nobody reads it as a spec. |

If you forget all of it: **test observable behavior at the lowest level that can catch the bug, keep every test deterministic and self-contained, substitute only at boundaries you don't control and only through an adapter you do own, prove every test can fail, and treat a flaky test as a bug — never as noise to retry away.** The single highest-leverage habit is testing behavior over implementation (§1): get that wrong and the suite fights every refactor; get it right and it becomes the thing that lets you change code without fear.

---

## References

- `references/frameworks.md` — runner mechanics per stack: how to double, how to fake time, what the isolation default is, how to parallelize safely (Jest/Vitest hoisting and async timers, pytest fixture scope and `monkeypatch`, JUnit instance lifecycle, `go test`, XCTest, RSpec).
- `references/e2e.md` — Playwright vs Cypress vs Testing Library: the waiting model per tool, locator priority, request interception, and `findBy*`/`getBy*`/`queryBy*`. **Read this before writing a component or e2e test** — the three tools spell the same idea differently and the snippets are not portable.

---

## Tone

Be direct and constructive. Lead with the highest-impact problems — tests that can't catch bugs, flaky tests, and implementation-coupled tests come before style. Skip praise for what's already sound; if the suite is solid, say so briefly and point out the one or two things that would make it faster or more faithful.
