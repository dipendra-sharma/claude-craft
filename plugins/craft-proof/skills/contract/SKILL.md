---
name: contract
description: Write the proof contract before changing any code — fixing a bug, adding a feature, or changing behavior in a project where the proof plugin is active. Turns the request into user-visible claims, each with one shell command that proves it, then walks the red-then-green proof loop so the stop gate lets the work finish.
---

# Proof contract

The proof hooks block code edits until `.proof/contract.json` exists and is valid. They also block finishing until every claim has passing proof on the current code. Work through these steps in order.

## 1. Read before you write

Open the code the request touches, the tests that cover it, and how tests are run in this project (a test script, a Makefile target, a package script). Find every caller of the code you will change. Note which existing tests must keep passing.

## 2. Write the contract

Create `.proof/contract.json` with the Write tool (shell writes into `.proof/` are blocked):

```json
{
  "goal": "Checkout total never goes below zero, whatever coupon is applied",
  "kind": "bugfix",
  "claims": [
    {
      "id": "C1",
      "claim": "A coupon larger than the cart gives a total of 0, not a negative number",
      "check": "/usr/bin/python3 -m unittest tests.test_cart -v",
      "fail_first": true
    },
    {
      "id": "C2",
      "claim": "Every existing behavior of the cart still works",
      "check": "./run-tests.sh"
    }
  ],
  "allowed_test_changes": [],
  "unverified": []
}
```

How to write each part:

- **goal**: what a user will see when this is done, in one sentence.
- **claim**: behavior someone could observe, not internals. "Total is 0 for an oversized coupon", not "clamp() returns max".
- **check**: one exact shell command that exits 0 only when the claim holds. Use the project's own test runner, written relative to the project folder with no leading `cd`. A command that cannot fail (`true`, `echo ...`, anything ending in `|| true`) is rejected.
- **fail_first**: `true` for the claim that proves a bug fix. You must run its check once while it fails (before the fix), then again after the fix while it passes.
- **allowed_test_changes**: leave this empty unless the user asked for a behavior change that makes an existing test wrong. Every entry needs the test's `path` and a `reason`. Otherwise you may add new tests to an existing test file, but its original lines cannot be changed or removed.
- **unverified**: anything the request asks for that cannot be checked here (a real device, production traffic, a paid service). Say why for each one. Never drop such an item silently.

The contract locks the first time any of its checks runs. After that, claims cannot change, so get them right before running anything.

## 3. Red, then green

1. Write the new test that captures the bug or feature first.
2. Run the `fail_first` claim's check exactly as written. It must fail. That failure is the proof the test can catch the problem.
3. Change the code.
4. Run every claim's check exactly as written, after your last edit. Any edit after a passing run makes that proof stale.

Run each check with exactly the text in `check`. Different text (extra flags, `| tail`, `2>&1`) is not recorded as proof.

## 4. Report

End with one line per claim: its id, what it shows, and the result of its last run. Then list every unverified item by name, and say it is unverified. Do not claim anything the proof does not show.

## Skills that work with this one

- `craft-proof:testing-best-practices` before writing the test behind a claim: test observable behavior, and see it fail first.
- `craft-proof:coding-best-practices` before writing the code that makes the claims true.
- `craft-proof:firebase-crash-fix` when the request is a Crashlytics crash; its reproduce-first loop becomes the `fail_first` claim.
