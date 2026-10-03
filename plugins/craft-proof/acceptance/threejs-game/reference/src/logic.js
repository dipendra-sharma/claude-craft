const PLAYER_SPEED = 10;
const PLAYER_RADIUS = 0.5;
const BULLET_SPEED = 30;
const FIRE_COOLDOWN = 0.25;
const SHIELD_SECONDS = 2;
const HIT_SCORE = 50;
const SURVIVAL_SCORE = 10;
const LEVEL_SECONDS = 30;
const LEVEL_SPEEDUP = 0.25;

function nextRandom(seed) {
  const advanced = (seed + 0x6d2b79f5) >>> 0;
  let t = advanced;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return { value: ((t ^ (t >>> 14)) >>> 0) / 4294967296, seed: advanced };
}

function between(min, max, unit) {
  return min + (max - min) * unit;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.z - b.z);
}

export function createGame({ seed, width = 20, depth = 40, spawnInterval = 0.5 }) {
  return {
    status: "playing",
    time: 0,
    score: 0,
    level: 1,
    player: { x: 0, z: depth / 2 - 2, lives: 3, shieldTime: 0 },
    asteroids: [],
    bullets: [],
    fireCooldown: 0,
    spawnTimer: 0,
    rng: seed >>> 0,
    nextId: 1,
    width,
    depth,
    spawnInterval,
  };
}

export function togglePause(state) {
  if (state.status === "gameover") return state;
  return { ...state, status: state.status === "playing" ? "paused" : "playing" };
}

function movePlayer(player, input, dt, width, depth) {
  const dx = (input.right ? 1 : 0) - (input.left ? 1 : 0);
  const dz = (input.back ? 1 : 0) - (input.forward ? 1 : 0);
  return {
    ...player,
    x: clamp(player.x + dx * PLAYER_SPEED * dt, -width / 2, width / 2),
    z: clamp(player.z + dz * PLAYER_SPEED * dt, 0, depth / 2),
    shieldTime: Math.max(0, player.shieldTime - dt),
  };
}

function spawnAsteroids(state, dt) {
  let { rng, nextId, spawnTimer } = state;
  const spawned = [];
  spawnTimer += dt;
  while (spawnTimer >= state.spawnInterval) {
    spawnTimer -= state.spawnInterval;
    const draws = [];
    for (let i = 0; i < 3; i += 1) {
      const next = nextRandom(rng);
      rng = next.seed;
      draws.push(next.value);
    }
    spawned.push({
      id: nextId,
      x: between(-state.width / 2, state.width / 2, draws[0]),
      z: -state.depth / 2,
      radius: between(0.5, 1.5, draws[1]),
      speed: between(5, 10, draws[2]),
    });
    nextId += 1;
  }
  return { rng, nextId, spawnTimer, spawned };
}

function resolveBulletHits(asteroids, bullets) {
  const hitAsteroids = new Set();
  const hitBullets = new Set();
  for (const bullet of bullets) {
    const target = asteroids.find((a) => !hitAsteroids.has(a.id) && distance(a, bullet) < a.radius);
    if (target) {
      hitAsteroids.add(target.id);
      hitBullets.add(bullet.id);
    }
  }
  return {
    asteroids: asteroids.filter((a) => !hitAsteroids.has(a.id)),
    bullets: bullets.filter((b) => !hitBullets.has(b.id)),
    hits: hitAsteroids.size,
  };
}

function resolvePlayerHits(player, asteroids) {
  let current = player;
  const remaining = [];
  for (const asteroid of asteroids) {
    if (distance(asteroid, current) >= asteroid.radius + PLAYER_RADIUS) {
      remaining.push(asteroid);
      continue;
    }
    if (current.shieldTime === 0 && current.lives > 0) {
      current = { ...current, lives: current.lives - 1, shieldTime: SHIELD_SECONDS };
    }
  }
  return { player: current, asteroids: remaining };
}

export function step(state, input, dt) {
  if (state.status !== "playing") return state;

  const time = state.time + dt;
  const movedPlayer = movePlayer(state.player, input, dt, state.width, state.depth);

  let fireCooldown = Math.max(0, state.fireCooldown - dt);
  let nextId = state.nextId;
  let bullets = state.bullets;
  if (input.fire && fireCooldown === 0) {
    bullets = [...bullets, { id: nextId, x: movedPlayer.x, z: movedPlayer.z }];
    nextId += 1;
    fireCooldown = FIRE_COOLDOWN;
  }
  bullets = bullets
    .map((b) => ({ ...b, z: b.z - BULLET_SPEED * dt }))
    .filter((b) => b.z >= -state.depth / 2);

  const speedFactor = 1 + LEVEL_SPEEDUP * (state.level - 1);
  const movedAsteroids = state.asteroids
    .map((a) => ({ ...a, z: a.z + a.speed * speedFactor * dt }))
    .filter((a) => a.z <= state.depth / 2);

  const spawn = spawnAsteroids({ ...state, nextId }, dt);
  const shot = resolveBulletHits([...movedAsteroids, ...spawn.spawned], bullets);
  const crash = resolvePlayerHits(movedPlayer, shot.asteroids);

  const survived = Math.floor(time) - Math.floor(state.time);
  return {
    ...state,
    status: crash.player.lives === 0 ? "gameover" : "playing",
    time,
    score: state.score + shot.hits * HIT_SCORE + survived * SURVIVAL_SCORE,
    level: 1 + Math.floor(time / LEVEL_SECONDS),
    player: crash.player,
    asteroids: crash.asteroids,
    bullets: shot.bullets,
    fireCooldown,
    spawnTimer: spawn.spawnTimer,
    rng: spawn.rng,
    nextId: spawn.nextId,
  };
}
