---
type: llm
focus: { source: file, path: src/main.js }
weight: 2
---

PASS if this file does all of these: creates a three.js scene, camera and WebGLRenderer; calls step() from the logic module every animation frame; adds and removes meshes so asteroids and bullets on screen match the current state; maps keyboard keys to the input object (move, fire, pause, restart); shows score, lives and level on screen; and shows a game-over message with a way to restart.
FAIL if any of those is missing.
