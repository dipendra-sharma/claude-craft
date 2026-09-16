# Runner mechanics

**Currency stamp: 2026-09-06.** The principles in the parent skill are framework-independent; these are the knobs that actually make isolation, determinism and parallelism true in each runner. Verify against the installed version before relying on a specific API.

---

## Jest / Vitest

Near-identical surfaces, with traps that bite in both:

- **`vi.mock` / `jest.mock` are hoisted above imports.** The factory runs before any module-level variable is initialised, so a factory that closes over an outer variable throws. That is what `vi.hoisted()` exists for. `vi.doMock` is the non-hoisted form and only affects *subsequent* dynamic imports.
- **Fake timers plus `await` deadlock.** Advancing synchronously (`vi.advanceTimersByTime`) doesn't let queued microtasks run, so an awaited promise behind a timer never resolves. Use the async advancers (`vi.advanceTimersByTimeAsync`, `vi.runAllTimersAsync`). `vi.setSystemTime` / `jest.setSystemTime` freeze the clock for §7.
- **Isolation is configuration, not default virtue.** `restoreMocks`/`mockReset`/`clearMocks` decide whether a spy leaks into the next test. Set them once in config rather than remembering per file.
- **`expect.assertions(n)`** is how you make an async test that silently ran no assertions fail (§9).

## pytest

- **Fixture scope**: `function` (default), `class`, `module`, `package`, `session`. A session-scoped fixture holding mutable state is order-coupling wearing a helpful hat (§14).
- **`monkeypatch` unwinds at the end of the requesting function or fixture.** For anything broader use `pytest.MonkeyPatch.context()` explicitly — a session fixture that monkeypatches is a common source of cross-test leakage.
- **`@pytest.mark.parametrize` is how §6's table-driven test is spelled** — data varies, body stays straight-line, each row reports as its own test.
- `pytest.raises` is the assertion for the failure path; don't wrap it in a bare `try`.

## JUnit 5 (Jupiter)

- **Default test instance lifecycle is `PER_METHOD`** — a fresh instance per test, which is exactly *why* `@BeforeAll`/`@AfterAll` must be static. This is the isolation guarantee of §7, given to you for free.
- **`@TestInstance(Lifecycle.PER_CLASS)`** shares one instance across the class (letting `@BeforeAll` be non-static) and **disables parallel execution for that class** unless you also mark `@Execution(CONCURRENT)`. That is the §7-vs-§16 trade made concrete.
- `@ParameterizedTest` + `@MethodSource`/`@CsvSource` for table-driven; AssertJ's `assertThat` for the expressive matchers §8 asks for.

## go test

- Table-driven with subtests is the idiom: `for _, tc := range cases { t.Run(tc.name, func(t *testing.T) { ... }) }`.
- `t.Parallel()` inside a subtest opts it into concurrency — and every parallel subtest shares the parent's scope, so capture loop variables deliberately (fixed for the loop-var case in Go 1.22+, still worth checking).
- `t.Cleanup` is the teardown that runs even on failure; `testing.Short()` gates the slow layer for §16.

## XCTest

- One instance per test method, `setUpWithError`/`tearDownWithError` per test — the same `PER_METHOD` isolation as JUnit.
- `XCTestExpectation` + `waitForExpectations` (or `async` test methods) for async; never a `sleep` (§13).
- `measure {}` blocks are performance tests and belong in a separate, non-blocking target.

## RSpec

- `let` is lazy and memoized per example; `let!` forces it in a `before`. A `let` that mutates shared state is a Mystery Guest (§10).
- `described_class` keeps the test honest when a class is renamed.
- Random order is **not** the default — RSpec runs in defined order unless `config.order = :random` is set, and the generated `spec_helper` ships that line commented out. Turn it on and pass `--seed` to reproduce a failure; it is the cheapest test-interdependence detector you have (§14).
