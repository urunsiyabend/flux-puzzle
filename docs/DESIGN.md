# FLUX — Design Spec (v3: zen model)

## Vision
A calm, one-finger rotate-to-connect puzzle. The reward is the moment the whole
circuit lights up — not a score. Genre peers: Infinity Loop, Energy, Flow Free.

## Why v2 (pressure model) was dropped
v2 layered four separate systems on one level: a move counter, a computed *par*,
a move *budget* with fail, and a 3-star rating that also gated worlds. The HUD
read `9 moves left · par 14 · best 17 · ★★☆`.

- **Too much to track for a casual game.** Four numbers that all measure the same
  thing (taps) but mean different things.
- **Punishes how players read the board.** In a rotation puzzle, spinning a tile
  is how you find out what it can connect to. Counting taps against a hidden
  global optimum turns exploration into a penalty.
- **Par is opaque.** The optimum comes from a branch-and-bound solver over
  clockwise-only rotations; no player can reason about it mid-level.
- **Star gates force replay.** Players had to grind earlier levels for stars
  before seeing new mechanics.
- **Move-limit pressure fits a different game.** Royal Match / Candy Crush are
  stochastic (cascades, refills) with boosters and lives around the fail screen.
  A deterministic rotation puzzle has no randomness for a budget to play against.

## Core mechanic (unchanged)
- Grid of tiles, each a connector mask (N/E/S/W bits).
- **One finger, one direction:** tap rotates a tile +90° clockwise.
- Win = every connector mutually matched, none off-board/into-holes. Energy floods
  from a source so progress is always visible.
- Mechanic layers by world: locked tiles (W2), holes (W3), everything together (W4).
  One new idea at a time, announced in a single line when the world starts.

## Rules of the zen model
- **No counters during play.** The HUD shows only the level number and world name.
- **No fail state.** Undo, Hint and Restart stay as comfort tools.
- **Linear progression.** Solving a level unlocks the next; worlds only group levels.
- **Completion is the reward.** Win panel: `SOLVED` → `NEXT`. On a world boundary it
  names the next world and its new idea.
- Level select marks solved levels with a lit node (●) and shows `solved / total`.

## What stays in the code
- The move count is still recorded per level in the save (`completed`), so a later
  optional "perfect solve" badge or stats screen can use it without migrating saves.
- `Generator.optimal_moves` (par solver) is kept and tested but not shown in game.

## Determinism & tests
- Everything seeded; restart reproduces the identical puzzle.
- Tests cover rules, generation/solvability, holes, locked tiles, the solver,
  hints, world structure and save progression.
