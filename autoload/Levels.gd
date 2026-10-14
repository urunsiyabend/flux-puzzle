extends Node

# Level catalogue, organised into WORLDS that each introduce one new mechanic.
# Boards are produced deterministically by the Generator, so every level is
# solvable and restarting re-creates the identical puzzle.
#
#   World 1 (1-6)   : basics — rotate to connect
#   World 2 (7-12)  : + LOCKED tiles (fixed anchors you must plan around)
#   World 3 (13-18) : + HOLES (irregular, non-rectangular boards)
#   World 4 (19-24) : holes + locked + dense loops (mastery)
#
# Worlds gate on TOTAL STARS, so the star rating is meaningful: to reach a later
# world you must go back and earn more stars on earlier levels.

const PER_WORLD := 6
const WORLD_NAMES := ["Spark", "Anchor", "Fracture", "Overload"]
const WORLD_STAR_GATES := [0, 8, 20, 34]   # total stars required to enter world i

var configs: Array = []
var current_level := 0

func _ready() -> void:
	_build_catalogue()

func _build_catalogue() -> void:
	# [w, h, loop, holes, locked]
	var recipe := [
		# World 1 — basics
		[3, 3, 0.0, 0, 0], [3, 4, 0.0, 0, 0], [4, 4, 0.0, 0, 0],
		[4, 4, 0.08, 0, 0], [4, 5, 0.08, 0, 0], [5, 5, 0.1, 0, 0],
		# World 2 — locked tiles
		[4, 5, 0.06, 0, 1], [5, 5, 0.08, 0, 2], [5, 6, 0.08, 0, 2],
		[5, 6, 0.1, 0, 3], [6, 6, 0.1, 0, 3], [6, 7, 0.12, 0, 4],
		# World 3 — holes
		[5, 6, 0.08, 3, 0], [6, 6, 0.1, 4, 0], [6, 7, 0.1, 5, 0],
		[6, 7, 0.12, 6, 0], [7, 7, 0.12, 7, 0], [7, 8, 0.14, 8, 0],
		# World 4 — mastery
		[6, 7, 0.14, 4, 2], [7, 8, 0.15, 6, 3], [7, 8, 0.16, 7, 3],
		[7, 9, 0.18, 8, 4], [8, 9, 0.18, 9, 4], [8, 10, 0.2, 10, 5],
	]
	configs.clear()
	for i in range(recipe.size()):
		var r = recipe[i]
		configs.append({
			"w": r[0], "h": r[1], "loop": r[2], "holes": r[3], "locked": r[4],
			"seed": 104729 + i * 2179,
		})

func count() -> int:
	return configs.size()

func world_of(level: int) -> int:
	return level / PER_WORLD

func world_name(level: int) -> String:
	return WORLD_NAMES[clampi(world_of(level), 0, WORLD_NAMES.size() - 1)]

func tier(level: int) -> int:
	return clampi(world_of(level) + 1, 1, 3)

func gate_for_world(w: int) -> int:
	return WORLD_STAR_GATES[clampi(w, 0, WORLD_STAR_GATES.size() - 1)]

# Build the board for a level (deterministic).
func get_board(level: int) -> Board:
	var c = configs[level]
	return Generator.generate(int(c["w"]), int(c["h"]), int(c["seed"]), float(c["loop"]), int(c["holes"]), int(c["locked"]))

var _par_cache := {}

# Par = the TRUE minimum number of clockwise taps to solve the board (the move
# economy's optimum), computed by the solver. Tiles rotate one way only, so this
# is honest and achievable.
func par(board: Board) -> int:
	return Generator.optimal_moves(board)

# Cached par per level (solver is deterministic, so par is fixed per level).
func par_for(level: int) -> int:
	if not _par_cache.has(level):
		_par_cache[level] = par(get_board(level))
	return int(_par_cache[level])

# --- move budget / pressure ramp ------------------------------------------
# World 1 is frictionless (no fail). Budget tightens toward near-miss by World 4.
const WORLD_BUDGET_MULT := [0.0, 2.2, 1.6, 1.3]

func world_no_fail(w: int) -> bool:
	return w <= 0

func budget_for(level: int) -> int:
	var w := world_of(level)
	if world_no_fail(w):
		return 99999
	var p := par_for(level)
	var mult: float = WORLD_BUDGET_MULT[clampi(w, 0, WORLD_BUDGET_MULT.size() - 1)]
	return max(int(ceil(p * mult)), p + 2)

func level_no_fail(level: int) -> bool:
	return world_no_fail(world_of(level))

func stars_for(moves: int, par_value: int) -> int:
	if par_value <= 0:
		return 3
	if moves <= par_value:
		return 3
	if moves <= int(ceil(par_value * 1.5)):
		return 2
	return 1

# --- star-based progression ----------------------------------------------

func best_stars(level: int) -> int:
	if not Save.is_completed(level):
		return 0
	return stars_for(Save.best_moves(level), par(get_board(level)))

func total_stars() -> int:
	var t := 0
	for i in range(count()):
		t += best_stars(i)
	return t

func world_unlocked(w: int) -> bool:
	return total_stars() >= gate_for_world(w)

# A level is playable when the linear progression has reached it AND its world's
# star gate is satisfied.
func is_unlocked(level: int) -> bool:
	if level < 0 or level >= count():
		return false
	if not Save.is_unlocked(level):
		return false
	return world_unlocked(world_of(level))
