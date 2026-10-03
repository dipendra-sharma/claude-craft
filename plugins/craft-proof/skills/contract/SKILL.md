---
name: contract
description: Write the proof contract before changing code or writing any deliverable — a bug fix, a feature, a behavior change, or a document, plan, report, analysis or data file — wherever the craft-proof plugin is active. Turns the request into user-visible claims, each with evidence the hooks can re-check (a command, a quoted source, a calculation, file contents, or a judged rubric), then walks the proof loop so the stop gate lets the work finish.
---

# Proof contract

The proof hooks block code edits and deliverable writes until `.proof/contract.json` exists and is valid. They block finishing until every claim is proven on the final content. Commands are proven by the hooks recording their real results; sources, calculations, file contents and rubrics are re-checked by the hooks when you finish. So the only way through is real evidence. Work through these steps in order.

For a document, plan, report, analysis or data file, skip to "Deliverables" below.

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
- **kind**: `bugfix`, `feature` or `change` for code; `deliverable` for documents and other non-code work.
- **claim**: behavior someone could observe, not internals. "Total is 0 for an oversized coupon", not "clamp() returns max".
- **check**: one shell command that exits 0 only when the claim holds, written relative to the project root with no leading `cd`. Use the project's own test runner. Commands may be chained with `&&`, but `|`, `||` and `;` are rejected because they can hide a failure, and so is anything that cannot fail (`true`, `echo ...`).
- **fail_first**: `true` for the claim that proves a bug fix. Its check must be seen failing on the unfixed code, then passing after the fix, with the same test files both times. A check that cannot start ("command not found") does not count as failing.
- **allowed_test_changes**: existing test files, test settings (`pytest.ini`, `jest.config.*`, `analysis_options.yaml`, CI workflows) and the scripts your checks run are read-only. Put new tests in new files. Only when the user asked for a behavior change that makes an existing test wrong, list that file here with a `reason`, before running any check.
- **unverified**: anything the request asks for that cannot be checked here (a real device, production traffic, a paid service), with why. These are shown to the user when you finish. Never drop such an item silently.

The contract locks as soon as any check's program runs, in any form. After that you may only add claims or unverified items; the goal, the kind, existing claims and `allowed_test_changes` stay as they were. So get the claims right before running anything.

## 3. Break it into a todo list

With 3 or more claims, the hooks block the first edit until a todo list exists. Create one item per claim with `TaskCreate`, putting the claim id at the start of the subject (`C2: oversized coupon gives 0`); add items for other steps as needed. If `TaskCreate` shows only as a deferred name, load it with `ToolSearch` (`select:TaskCreate,TaskUpdate,TaskList,TaskGet`).

Mark an item `in_progress` before you start it. Marking it `completed` is refused while any claim it names is not proven, so run the claim's check (or fix the content) first. Before you finish, every claim must be named by an item and no item may be left open; if one is truly blocked, leave it open and add a line to its description with `TaskUpdate`: `Blocked: <the reason>`.

## 4. Red, then green

1. Write the new test that captures the bug or feature, in a new file.
2. Run the `fail_first` claim's check exactly as written. It must fail. That failure is the proof the test can catch the problem.
3. Change the code. Do not touch the new test after its red run.
4. Run every claim's check exactly as written, after your last code edit. Any later code edit makes that proof stale; edits to documentation do not.

Run each check from the project root, in the foreground, with exactly the text in `check`. A run from another folder, a run in the background, or different text (extra flags, `| tail`) is not recorded as proof.

## 5. Report

End with one line per claim: its id, what it shows, and the result of its last run. Then list every unverified item by name and say it is unverified. Do not claim anything the proof does not show.

## Deliverables

A deliverable is any document, plan, report, analysis or data file you write (`.md`, `.txt`, `.rst`, `.csv` and similar inside a git repository, and any file at all outside one). Every deliverable you write must be named by at least one claim. Use `"kind": "deliverable"` and pick the evidence that fits each claim:

```json
{
  "goal": "A one-page rollout plan the team can follow on Monday",
  "kind": "deliverable",
  "claims": [
    {"id": "C1", "claim": "The plan has risks, owners and a rollback step", "file": {"path": "docs/rollout.md", "contains": ["^## Risks", "^## Rollback", "Owner:"]}},
    {"id": "C2", "claim": "The vendor's rate limit is 100 requests a minute", "source": {"location": "https://vendor.example/pricing", "quote": "allows 100 requests per minute"}},
    {"id": "C3", "claim": "Yearly cost is 50,400", "calc": {"expression": "4200 * 12", "result": "50400"}},
    {"id": "C4", "claim": "Every risk has a concrete mitigation", "rubric": {"target": "docs/rollout.md", "criteria": "PASS if every risk has a mitigation a person could act on. FAIL if any risk has none or only says 'monitor'."}}
  ],
  "unverified": ["Team availability on Monday: not visible from here"]
}
```

- **file**: the path and the regular expressions it must contain, checked line by line on the final file. Use it for structure and required facts.
- **source**: where a fact came from, with an exact quote of at least a short phrase. The hooks re-open the link or file and confirm the quote is there, so copy it exactly; HTML tags, spacing and letter case are ignored.
- **calc**: every number you computed, with the expression and the result. The hooks recompute it (`qalc`, or `bc` for plain arithmetic). Work numbers out with `craft-proof:calculator`, never in your head.
- **rubric**: a quality only judgement can check. Write PASS and FAIL conditions. A separate judge reads the target (a file path, or `"reply"` for your final answer) once everything else passes. Prefer file, source and calc claims; use a rubric only for what they cannot express.

Skills that lead for deliverables: `craft-proof:product-spec` for specs and requirements, `craft-proof:decision-partner` for recommendations and comparisons, `craft-proof:calculator` for any number, `craft-proof:dashboard-best-practices` for dashboard plans, `craft-proof:github-bug-report` for bug reports, and `craft-proof:explain-anything` for explanations.

## Skills that work with this one

- `craft-proof:testing-best-practices` before writing the test behind a claim: test observable behavior, and see it fail first.
- `craft-proof:coding-best-practices` before writing the code that makes the claims true.
- `craft-proof:firebase-crash-fix` when the request is a Crashlytics crash; its reproduce-first loop becomes the `fail_first` claim.
