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
# Progression is linear: solving a level unlocks the next. Worlds only group
# levels and pace the introduction of new mechanics.

const PER_WORLD := 6
const WORLD_NAMES := ["Spark", "Anchor", "Fracture", "Overload"]
const WORLD_INTROS := [
	"Tap a tile to turn it",
	"Locked tiles stay put",
	"Some boards have holes",
	"Everything together",
]

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

func world_intro(w: int) -> String:
	return WORLD_INTROS[clampi(w, 0, WORLD_INTROS.size() - 1)]

func is_world_start(level: int) -> bool:
	return level % PER_WORLD == 0

# Build the board for a level (deterministic).
func get_board(level: int) -> Board:
	var c = configs[level]
	return Generator.generate(int(c["w"]), int(c["h"]), int(c["seed"]), float(c["loop"]), int(c["holes"]), int(c["locked"]))
