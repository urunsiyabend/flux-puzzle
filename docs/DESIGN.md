# FLUX — Design Spec (v2: pressure model)

## Vision
A one-finger rotate-to-connect puzzle with a **move economy**: the mastery axis is
solving each circuit in as few clockwise taps as possible. Market-aligned with
move-limited puzzle leaders (Royal Match, Candy Crush) and the pressure philosophy
of Spyke's Tile Busters, while keeping the pure single-tap feel (no second rotation
direction).

## Core mechanic (unchanged)
- Grid of tiles, each a connector mask (N/E/S/W bits).
- **One finger, one direction:** tap rotates a tile +90° clockwise.
- Win = every connector mutually matched, none off-board/into-holes. Energy floods
  from a source so progress is always visible.
- Mechanic layers by world: locked tiles (W2), holes/irregular boards (W3), both +
  dense loops (W4). Introduce one new idea at a time.

## The move economy (the new part)
Each tap is a **move**. Because rotation is clockwise-only, the cost to bring a tile
from rotation `r` to a target orientation is `(target - r) mod 4` taps (a 2-periodic
"straight" piece needs at most 1).

### Par = true optimum
`par` is the **minimum total clockwise taps** over all valid solutions, found by a
branch-and-bound solver at level build (cached). This is honest and achievable
(unlike the old `min(r,4-r)` which assumed two-way rotation and was unreachable).
Fallback for very large boards: the home-solution clockwise cost (an achievable upper
bound) if the solver exceeds its node budget.

### Move budget + fail (the pressure)
A level has a **move budget** = `par × worldMultiplier` (clamped to ≥ par+2).
Running out of moves without solving ⇒ **fail → Retry**. This creates the
"near-miss" moment that drives retention and (future) monetization.

### Difficulty / pressure ramp — FRICTIONLESS FIRST
Pressure is a dial that starts at zero. First sessions must be unloseable so the
player learns and forms the habit before any friction (Candy Crush / Royal Match
place difficulty walls *late*, not early).

| World | Name     | New mechanic         | Fail? | Budget multiplier |
|-------|----------|----------------------|-------|-------------------|
| 1     | Spark    | basics               | NO    | unlimited (teach) |
| 2     | Anchor   | locked tiles         | yes   | ~2.2× par (loose) |
| 3     | Fracture | holes                | yes   | ~1.6× par         |
| 4     | Overload | holes + locked + loops | yes | ~1.3× par (near-miss) |

- **World 1: no fail at all.** Move counter is shown but informational; the player
  cannot lose. ~100% win rate by design.
- Budget tightens world over world until W4 is genuine near-miss territory.

### Stars (mastery + replay)
Independent of fail; always earnable, including in World 1:
- ★★★ = solved in ≤ par (optimal)
- ★★ = solved in ≤ ceil(par × 1.5)
- ★ = solved
Stars gate later worlds (total-star thresholds) → replay for mastery is the core
retention loop even before fail pressure appears.

### Self-competition ("race yourself")
Each level stores your **best move count** (PB). The HUD shows it as a target.
This is the local, offline seed of a future online leaderboard (Spyke-style
competitive meta). No backend in v1.

## HUD
- World-1 (no fail): `moves N · par M · ★ preview` (counts up).
- Fail worlds: `N moves left` (counts DOWN like Candy Crush) · `par M` · `best P` ·
  star preview.
- Out-of-moves overlay: "Out of moves" + Retry + Levels.
- Win overlay: stars by `par`, moves used, PB, total stars, world-unlock banner.

## Monetization readiness (NOT in v1, architecture only)
The fail/near-miss screen is the natural home for future "+5 moves" / booster /
lives offers. Keep the fail flow and move economy isolated so an economy layer can
attach later without touching core rules. No IAP/ads/backend in v1.

## Determinism & tests
- Everything seeded; par is deterministic and cached per level.
- Tests: solver finds the true optimum on tiny boards; par is achievable and
  ≤ home cost; budget ramp is monotonic and ≥ par; World 1 is no-fail; star
  thresholds; existing rule/mechanic coverage stays green.
