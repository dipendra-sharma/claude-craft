import { test } from "node:test";
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const { createGame, step, togglePause } = await import(pathToFileURL(process.env.LOGIC_PATH).href);

const IDLE = { left: false, right: false, forward: false, back: false, fire: false };
const CLOSE = 1e-6;

function quietGame(overrides = {}) {
  return { ...createGame({ seed: 1, spawnInterval: Infinity }), ...overrides };
}

function asteroid(fields) {
  return { id: 101, x: 0, z: 0, radius: 1, speed: 0, ...fields };
}

function run(state, input, dt, times) {
  let current = state;
  for (let i = 0; i < times; i += 1) current = step(current, input, dt);
  return current;
}

function assertClose(actual, expected, label) {
  assert.ok(Math.abs(actual - expected) < CLOSE, `${label}: expected ${expected}, got ${actual}`);
}

test("a new game starts playing with 3 lives, no score, level 1 and the player at x 0, z 18", () => {
  const game = createGame({ seed: 3 });
  assert.equal(game.status, "playing");
  assert.equal(game.score, 0);
  assert.equal(game.level, 1);
  assert.equal(game.time, 0);
  assert.equal(game.player.lives, 3);
  assert.equal(game.player.shieldTime, 0);
  assert.equal(game.player.x, 0);
  assert.equal(game.player.z, 18);
  assert.deepEqual(game.asteroids, []);
  assert.deepEqual(game.bullets, []);
});

test("the same seed and inputs give identical games", () => {
  const inputs = (i) => ({ ...IDLE, left: i % 7 < 3, fire: i % 2 === 0 });
  let a = createGame({ seed: 7 });
  let b = createGame({ seed: 7 });
  for (let i = 0; i < 200; i += 1) {
    a = step(a, inputs(i), 1 / 60);
    b = step(b, inputs(i), 1 / 60);
  }
  assert.deepEqual(JSON.parse(JSON.stringify(a)), JSON.parse(JSON.stringify(b)));
});

test("different seeds spawn asteroids in different places", () => {
  const a = step(createGame({ seed: 1 }), IDLE, 1);
  const b = step(createGame({ seed: 2 }), IDLE, 1);
  assert.notDeepEqual(a.asteroids.map((x) => x.x), b.asteroids.map((x) => x.x));
});

test("step never changes the state it was given", () => {
  const start = quietGame({ asteroids: [asteroid({ z: -5, speed: 4 })] });
  const before = JSON.stringify(start);
  step(start, { ...IDLE, right: true, fire: true }, 0.1);
  togglePause(start);
  assert.equal(JSON.stringify(start), before);
});

test("the player moves 10 units per second", () => {
  const moved = run(quietGame(), { ...IDLE, right: true }, 0.1, 5);
  assertClose(moved.player.x, 5, "x after 0.5s right");
  const forward = step(quietGame(), { ...IDLE, forward: true }, 1);
  assertClose(forward.player.z, 8, "z after 1s forward");
});

test("the player stays inside the field", () => {
  assertClose(step(quietGame(), { ...IDLE, left: true }, 2).player.x, -10, "left edge");
  assertClose(step(quietGame(), { ...IDLE, right: true }, 2).player.x, 10, "right edge");
  assertClose(step(quietGame(), { ...IDLE, forward: true }, 3).player.z, 0, "front edge");
  assertClose(step(quietGame(), { ...IDLE, back: true }, 1).player.z, 20, "back edge");
});

test("asteroids spawn once per spawn interval at the far edge with values in range", () => {
  const game = step(createGame({ seed: 5, spawnInterval: 0.5 }), IDLE, 1);
  assert.equal(game.asteroids.length, 2);
  for (const rock of game.asteroids) {
    assertClose(rock.z, -20, "spawn z");
    assert.ok(rock.x >= -10 && rock.x <= 10, `x in field: ${rock.x}`);
    assert.ok(rock.radius >= 0.5 && rock.radius <= 1.5, `radius in range: ${rock.radius}`);
    assert.ok(rock.speed >= 5 && rock.speed <= 10, `speed in range: ${rock.speed}`);
  }
  assert.notEqual(game.asteroids[0].id, game.asteroids[1].id);
});

test("asteroids move toward the player at their speed", () => {
  const moved = step(quietGame({ asteroids: [asteroid({ x: 5, z: -10, speed: 4 })] }), IDLE, 0.5);
  assertClose(moved.asteroids[0].z, -8, "asteroid z");
});

test("asteroids move 25 percent faster for each level above 1", () => {
  const moved = step(quietGame({ time: 60, level: 3, asteroids: [asteroid({ x: 5, z: -10, speed: 4 })] }), IDLE, 1);
  assertClose(moved.asteroids[0].z, -4, "asteroid z at level 3");
});

test("asteroids that pass the near edge are removed without penalty", () => {
  const moved = step(quietGame({ asteroids: [asteroid({ x: 9, z: 19.9, speed: 10 })] }), IDLE, 0.1);
  assert.equal(moved.asteroids.length, 0);
  assert.equal(moved.player.lives, 3);
});

test("firing creates a bullet at the player that flies forward 30 units per second", () => {
  const fired = step(quietGame(), { ...IDLE, fire: true }, 0.01);
  assert.equal(fired.bullets.length, 1);
  assertClose(fired.bullets[0].x, 0, "bullet x");
  assertClose(fired.bullets[0].z, 17.7, "bullet z");
});

test("holding fire shoots at most once every 0.25 seconds", () => {
  const held = run(quietGame(), { ...IDLE, fire: true }, 0.1, 4);
  assert.equal(held.bullets.length, 2);
});

test("bullets that leave the far edge are removed", () => {
  const gone = step(quietGame({ bullets: [{ id: 201, x: 0, z: -19.5 }] }), IDLE, 0.1);
  assert.equal(gone.bullets.length, 0);
});

test("a bullet that hits an asteroid destroys both and scores 50", () => {
  const hit = step(quietGame({ asteroids: [asteroid({ x: 0, z: 10 })], bullets: [{ id: 201, x: 0, z: 10.5 }] }), IDLE, 0.01);
  assert.equal(hit.asteroids.length, 0);
  assert.equal(hit.bullets.length, 0);
  assert.equal(hit.score, 50);
});

test("an asteroid hitting the player costs a life, is removed and gives a 2 second shield", () => {
  const hit = step(quietGame({ asteroids: [asteroid({ x: 0, z: 18 })] }), IDLE, 0.01);
  assert.equal(hit.player.lives, 2);
  assertClose(hit.player.shieldTime, 2, "shield");
  assert.equal(hit.asteroids.length, 0);
});

test("collision distance is the asteroid radius plus 0.5", () => {
  const near = step(quietGame({ asteroids: [asteroid({ x: 1.4, z: 18 })] }), IDLE, 0.001);
  const far = step(quietGame({ asteroids: [asteroid({ x: 1.6, z: 18 })] }), IDLE, 0.001);
  assert.equal(near.player.lives, 2);
  assert.equal(far.player.lives, 3);
});

test("the shield blocks damage while it lasts", () => {
  const shielded = quietGame({ player: { x: 0, z: 18, lives: 2, shieldTime: 2 }, asteroids: [asteroid({ x: 0, z: 18 })] });
  const after = step(shielded, IDLE, 0.01);
  assert.equal(after.player.lives, 2);
  assert.equal(after.asteroids.length, 0);
});

test("losing the last life ends the game and later steps change nothing", () => {
  const over = step(quietGame({ player: { x: 0, z: 18, lives: 1, shieldTime: 0 }, asteroids: [asteroid({ x: 0, z: 18 })] }), IDLE, 0.01);
  assert.equal(over.player.lives, 0);
  assert.equal(over.status, "gameover");
  const later = step(over, { ...IDLE, right: true, fire: true }, 1);
  assert.deepEqual(later, over);
});

test("surviving scores 10 for each whole second crossed", () => {
  assert.equal(run(quietGame(), IDLE, 0.6, 2).score, 10);
  assert.equal(step(quietGame(), IDLE, 2.5).score, 20);
});

test("the level rises every 30 seconds", () => {
  assert.equal(step(quietGame({ time: 29.9 }), IDLE, 0.2).level, 2);
  assert.equal(step(quietGame({ time: 59.95 }), IDLE, 0.1).level, 3);
});

test("pausing freezes the game until it is unpaused", () => {
  const paused = togglePause(quietGame());
  assert.equal(paused.status, "paused");
  assert.deepEqual(step(paused, { ...IDLE, right: true }, 1), paused);
  const resumed = togglePause(paused);
  assert.equal(resumed.status, "playing");
  assertClose(step(resumed, { ...IDLE, right: true }, 0.5).player.x, 5, "moves after resume");
});
