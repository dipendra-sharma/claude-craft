---
name: calculator
description: >-
  Do any math, unit/metric conversion, scientific calculation, or currency
  conversion by shelling out to the `qalc` (Qalculate!) CLI instead of computing
  by hand. Use this whenever the user asks to calculate, evaluate, or simplify an
  expression; convert between units (length, mass, temperature, time, data,
  speed, area, volume, etc.); convert currencies or exchange rates; do
  trigonometry, logs, roots, factorials, percentages, or physical-constant math;
  or convert number bases. Trigger even on a bare expression like "45 mph in
  km/h", "17% of 340", "2^32", or "500 USD to INR". ALWAYS invoke this skill when
  a calculation, any unit/metric conversion, or a currency conversion is
  involved — even for trivial-looking tasks — rather than computing it yourself.
---

# Calculator (qalc)

Run the `qalc` CLI for calculations, conversions, and currency. Always prefer it
over mental math.

## Run it

```bash
qalc -t "<expression>"        # -t = terse, prints just the result
qalc -t -e "100 USD to EUR"   # add -e for ANY currency (refreshes live rates)
```

One quoted expression per call. Report the result plainly.

## Syntax essentials

- **Math:** `+ - * /`, `^` power, `!` factorial, `mod`, `//` int-div; `340 * 17%` (percent), `52 to factors`, `25/4 to fraction`.
- **Scientific:** `sqrt() cbrt() root(x;n) ln() log(x;b) exp() sin() cos() tan() abs()`; args split by `;`. Angles are radians — use `deg` (`sin(30 deg)`). Constants: `pi e c planck G`.
- **Units/metric:** convert with `to` — `20 miles/2h to km/h`, `1.74 m to ft`, `2 GB to MB`, `3 days to seconds`. Temperature: use `°F`/`°C` or `fahrenheit`/`celsius` (bare `F`/`C` = farad/coulomb). `to base` for SI base units; `to -ft` forces a single unit.
- **Currency:** convert like any unit but with `-e` — `qalc -t -e "500 EUR to JPY"`. ISO codes (USD, EUR, INR, GBP…).
- **Bases:** `52 to bin`, `255 to hex`, `0x3f` (hex input), `52 to base 32`, `1978 to roman`.

## When unsure / complex work

Ask qalc instead of guessing syntax:
`qalc -h` (options) · `qalc --list-functions <term>` · `qalc --list-units <term>` · `echo "help <name>" | qalc` (function usage) · `echo "info <name>" | qalc`.

## Examples

- `45 mph in km/h` → `qalc -t "45 mph to km/h"` → `72.42048 km/h`
- `250 USD in INR` → `qalc -t -e "250 USD to INR"` → report the amount
- `sin 30° + log₂ 8` → `qalc -t "sin(30 deg) + log(8;2)"` → `3.5`
- `integral of x^2 from 0 to 3` → `qalc -t "integrate(x^2;0;3)"` → `9`

If `qalc` is missing: `brew install qalculate` (macOS) or `apt install qalc` (Debian/Ubuntu).
