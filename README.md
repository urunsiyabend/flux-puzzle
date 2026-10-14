# FLUX — energy-circuit rotation puzzle

A minimalist, one-finger mobile puzzle built in **Godot 4.7** (GDScript, portrait,
Android-first). Tap any tile to rotate it; align every connector so the whole
circuit links up and energy flows from the source through the entire network.

| Menu | Puzzle | Solved |
|------|--------|--------|
| neon logo + Play/Levels/Sound | lit source + dim wires | full network glows cyan |

## The mechanic

Each tile carries connectors pointing in up to four directions. A single tap
rotates a tile 90° clockwise. A level is **solved** when every connector is
mutually matched with its neighbour and none point off the board. Energy floods
outward from a central **source** node through matched connectors, so partial
progress is always visible — unconnected tiles stay dim, connected ones light up.

The rules are fully deterministic, which makes the puzzle generator and solver
reliable (see below).

## Architecture

```
project.godot            # mobile renderer, 1080x1920 portrait, touch+mouse
autoload/
  Palette.gd             # single source of colours + type scale
  Save.gd                # JSON save: progress, best moves, settings
  Audio.gd               # 100% procedural SFX (synthesized to AudioStreamWAV)
  Levels.gd              # 24-level catalogue + par / star logic
  Shot.gd                # dev-only screenshot harness (inert unless FLUX_SHOT set)
scripts/
  Puzzle.gd              # pure rules: direction bitmasks, rotation, opposite
  Board.gd               # a puzzle instance: solved masks + player rotations,
                         #   is_solved(), unmatched_count(), hint_cell()
  Generator.gd           # solvable-by-construction generator + backtracking solver
  BoardView.gd           # single-pass _draw() renderer, touch input, animation,
                         #   energy flood-fill from the source
  UI.gd / Backdrop.gd    # shared neon button/label factory + animated background
  Main.gd / LevelSelect.gd / Game.gd   # the three screens
scenes/
  Main.tscn / LevelSelect.tscn / Game.tscn
tests/run_tests.gd       # headless test suite
```

### Generation & solving

* **Generator** builds a connected graph over the grid (randomized-DFS spanning
  tree, plus a tunable number of extra loop edges), reads off each tile's
  connector mask, then scrambles rotations. Because the solved orientation always
  exists, **every generated level is guaranteed solvable**. Generation is
  deterministic per seed, so *Restart* reproduces the identical puzzle.
* **Solver** (`Generator.solve_count`) is a row-major backtracker with
  border-pruned domains. It validates solvability and can detect uniqueness
  (used by the tests).

### Difficulty curve

24 levels, grids growing 3×3 → 8×11 with increasing loop density, split into three
colour-coded tiers (easy / medium / hard). Star rating (★/★★/★★★) compares your
move count to a computed *par* (minimum rotations back to the home solution).

## Features

- Polished main menu, level select with lock state + earned stars, gameplay HUD
- One-finger rotation, smooth per-tile rotation animation, energy flood feedback
- Win detection + completion pulse + animated win panel
- **Undo**, **Hint** (highlights a misaligned tile), **Restart**
- Persistent save (progress, best moves, SFX setting)
- Fully procedural audio and visuals — no external asset licensing

## Run it

Desktop (from the project folder):

```bash
godot --path .                 # or open project.godot in the Godot editor
```

### Automated tests

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

Covers rotation math, win conditions, invalid/off-board moves, generator
solvability for several sizes, the solver, the level catalogue, and progression.
Exit code 0 = all pass (currently **65/65**).

## Android export

The project is pre-configured (`export_presets.cfg`, portrait orientation,
`org.flux.circuit`, arm64 + armv7, `debug.keystore` included). Two prerequisites
are **not** bundled and must be installed once:

1. **Export templates** for Godot 4.7.2 — in the editor:
   *Editor → Manage Export Templates → Download and Install*
   (or place them under `~/.local/share/godot/export_templates/4.7.2.stable/`).
2. **Android SDK** path — set under *Editor → Editor Settings → Export → Android*.
   An SDK with build-tools/platform-tools/NDK is already present at
   `~/Android/Sdk` on this machine.

Then build the APK headlessly:

```bash
godot --headless --path . --export-debug "Android" build/flux.apk
```

> Note: the actual APK build was **not** run here because the export templates
> were not installed (downloading them is a network action left to you). Every
> other step — launch, gameplay, solving, progression, saving, and the test
> suite — was verified at runtime.
