---
description: Build a complete three.js game from a precise rule spec; hidden acceptance tests are run on the workspace after the eval.
runs: 2
max_turns: 150
timeout_seconds: 2700
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, TaskCreate, TaskUpdate, TaskList, TaskGet]
---

Build a 3D browser game called "Asteroid Dodge" in this project using three.js. three.js 0.186.1 is already installed in node_modules/three. There is no network access, so do not install anything else. Use `/usr/local/bin/node` (Node 22) to run JavaScript; plain `node` may not be on the PATH.

Files to create:
- `index.html`: loads `src/main.js` as an ES module, with an import map that maps "three" to `./node_modules/three/build/three.module.js`.
- `src/logic.js`: all game rules. It must be pure: no three.js, no DOM, no `Date.now`, no `Math.random`. It exports exactly the API below.
- `src/main.js`: three.js rendering, keyboard input (arrow keys or WASD to move, Space to fire, P to pause, Enter to restart after game over), a heads-up display showing score, lives and level, and a game-over screen. It calls `step()` once per animation frame.
- Automated tests for the rules, runnable with `/usr/local/bin/node --test`.

## src/logic.js API

- `createGame(options)` returns a new state. `options`: `{ seed, width = 20, depth = 40, spawnInterval = 0.5 }`. `seed` is a required integer.
- `step(state, input, dt)` returns the next state and never changes the `state` it was given. `input` is `{ left, right, forward, back, fire }` (booleans); `dt` is in seconds.
- `togglePause(state)` returns a new state with status switched between "playing" and "paused".

The state is a plain object with at least: `status` ("playing", "paused" or "gameover"), `time` (seconds played), `score`, `level`, `player: { x, z, lives, shieldTime }`, `asteroids: [{ id, x, z, radius, speed }]`, `bullets: [{ id, x, z }]`, `fireCooldown`, `spawnTimer`, `width`, `depth`, `spawnInterval`, plus whatever the seeded random generator needs.

A new game: status "playing", time 0, score 0, level 1, player at x 0 and z = depth/2 − 2 with 3 lives and shieldTime 0, no asteroids or bullets, fireCooldown 0, spawnTimer 0.

## Rules, applied in this order inside one step

1. If status is not "playing", return the state unchanged.
2. `time` increases by `dt`.
3. The player moves 10 units per second: left is −x, right is +x, forward is −z, back is +z. x is clamped to [−width/2, width/2] and z to [0, depth/2].
4. `shieldTime` drops by `dt`, never below 0.
5. Firing: `fireCooldown` drops by `dt`, never below 0. If `input.fire` is true and `fireCooldown` is 0, add a bullet at the player's x and z and set `fireCooldown` to 0.25.
6. Bullets move −z at 30 units per second and are removed once z < −depth/2.
7. Asteroids move +z at `speed × (1 + 0.25 × (level − 1))` units per second and are removed once z > depth/2, with no penalty.
8. Spawning: `spawnTimer` increases by `dt`; while `spawnTimer ≥ spawnInterval`, subtract `spawnInterval` and spawn one asteroid at z = −depth/2 with x uniform in [−width/2, width/2], radius uniform in [0.5, 1.5] and speed uniform in [5, 10], all drawn from a generator seeded by `seed`. Every asteroid gets a unique id.
9. A bullet whose distance (on x and z) to an asteroid's centre is less than that asteroid's radius destroys both; score increases by 50 per asteroid destroyed.
10. An asteroid whose distance to the player is less than its radius + 0.5 is removed. If `shieldTime` is 0, the player loses a life and `shieldTime` becomes 2. When lives reach 0, status becomes "gameover".
11. Score increases by 10 for each whole second that `time` crossed during this step (`floor(new time) − floor(old time)`).
12. `level` becomes `1 + floor(time / 30)`.

The same seed and the same inputs must always produce identical states.
