---
name: contract
description: Write the proof contract before changing any code — fixing a bug, adding a feature, or changing behavior in a project where the craft-proof plugin is active. Turns the request into user-visible claims, each with one shell command that proves it, then walks the red-then-green proof loop so the stop gate lets the work finish.
---

# Proof contract

The proof hooks block code edits until `.proof/contract.json` exists and is valid. They block finishing until every claim has passing proof on the current code. The proof itself is recorded by the hooks from the real result of each check, so the only way through is to run the checks. Work through these steps in order.

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
      "check": "/usr/bin/python3 -m unittest tests.test_oversized_coupon",
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
- **kind**: `bugfix`, `feature` or `change`.
- **claim**: behavior someone could observe, not internals. "Total is 0 for an oversized coupon", not "clamp() returns max".
- **check**: one shell command that exits 0 only when the claim holds, written relative to the project root with no leading `cd`. Use the project's own test runner. Commands may be chained with `&&`, but `|`, `||` and `;` are rejected because they can hide a failure, and so is anything that cannot fail (`true`, `echo ...`).
- **fail_first**: `true` for the claim that proves a bug fix. Its check must be seen failing on the unfixed code, then passing after the fix, with the same test files both times. A check that cannot start ("command not found") does not count as failing.
- **allowed_test_changes**: existing test files, test settings (`pytest.ini`, `jest.config.*`, `analysis_options.yaml`, CI workflows) and the scripts your checks run are read-only. Put new tests in new files. Only when the user asked for a behavior change that makes an existing test wrong, list that file here with a `reason`, before running any check.
- **unverified**: anything the request asks for that cannot be checked here (a real device, production traffic, a paid service), with why. These are shown to the user when you finish. Never drop such an item silently.

The contract locks as soon as any check's program runs, in any form. After that you may only add claims or unverified items; the goal, the kind, existing claims and `allowed_test_changes` stay as they were. So get the claims right before running anything.

## 3. Red, then green

1. Write the new test that captures the bug or feature, in a new file.
2. Run the `fail_first` claim's check exactly as written. It must fail. That failure is the proof the test can catch the problem.
3. Change the code. Do not touch the new test after its red run.
4. Run every claim's check exactly as written, after your last code edit. Any later code edit makes that proof stale; edits to documentation do not.

Run each check from the project root, in the foreground, with exactly the text in `check`. A run from another folder, a run in the background, or different text (extra flags, `| tail`) is not recorded as proof.

## 4. Report

End with one line per claim: its id, what it shows, and the result of its last run. Then list every unverified item by name and say it is unverified. Do not claim anything the proof does not show.

## Skills that work with this one

- `craft-proof:testing-best-practices` before writing the test behind a claim: test observable behavior, and see it fail first.
- `craft-proof:coding-best-practices` before writing the code that makes the claims true.
- `craft-proof:firebase-crash-fix` when the request is a Crashlytics crash; its reproduce-first loop becomes the `fail_first` claim.
