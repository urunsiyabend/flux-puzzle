class_name Board
extends RefCounted

# A concrete puzzle instance: solved connector masks plus the player's current
# rotation of each tile. Pure data + rules, no rendering.

var width: int
var height: int
var base: PackedInt32Array      # solved mask per cell
var rot: PackedInt32Array       # current rotation steps (0..3) per cell
var active: PackedByteArray     # 1 = real tile, 0 = hole (not part of the board)
var locked: PackedByteArray     # 1 = fixed tile the player cannot rotate

func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h
	base = PackedInt32Array()
	rot = PackedInt32Array()
	active = PackedByteArray()
	locked = PackedByteArray()
	base.resize(w * h)
	rot.resize(w * h)
	active.resize(w * h)
	locked.resize(w * h)
	for i in range(w * h):
		active[i] = 1

func is_hole(i: int) -> bool:
	return active[i] == 0

func is_locked(i: int) -> bool:
	return locked[i] == 1

func idx(row: int, col: int) -> int:
	return row * width + col

func in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < height and col >= 0 and col < width

# Current mask of a cell after applying the player's rotation.
func current_mask(i: int) -> int:
	return Puzzle.rotate(base[i], rot[i])

func neighbor(row: int, col: int, dir: int) -> Vector2i:
	var d: Vector2i = Puzzle.DELTA[dir]
	return Vector2i(col + d.x, row + d.y)  # returns (col,row)

# Rotate one tile clockwise by one quarter turn.
func rotate_cell(i: int) -> void:
	rot[i] = (rot[i] + 1) % 4

# True when every connector on every tile is mutually matched and none point
# off the board. Order-independent; alternate symmetric solutions also pass.
func is_solved() -> bool:
	for row in range(height):
		for col in range(width):
			var i := idx(row, col)
			var m := current_mask(i)
			for dir in Puzzle.DIRS:
				if m & dir:
					var nc := neighbor(row, col, dir)  # (col,row)
					if not in_bounds(nc.y, nc.x):
						return false
					var ni := idx(nc.y, nc.x)
					if (current_mask(ni) & Puzzle.opposite(dir)) == 0:
						return false
	return true

# Count of connectors that are NOT satisfied right now (for live feedback).
func unmatched_count() -> int:
	var bad := 0
	for row in range(height):
		for col in range(width):
			var i := idx(row, col)
			var m := current_mask(i)
			for dir in Puzzle.DIRS:
				if m & dir:
					var nc := neighbor(row, col, dir)
					if not in_bounds(nc.y, nc.x):
						bad += 1
					else:
						var ni := idx(nc.y, nc.x)
						if (current_mask(ni) & Puzzle.opposite(dir)) == 0:
							bad += 1
	return bad

# True when a tile is a valid hint target: a movable tile NOT currently showing
# its home orientation (so rotating it clockwise toward home genuinely helps).
# Using current_mask != base (not rot != 0) correctly ignores straight pieces
# that already show the right mask at a non-zero rotation.
func is_hint_candidate(i: int) -> bool:
	if active[i] == 0 or locked[i] == 1:
		return false
	var b := base[i]
	if b == 0 or b == Puzzle.ALL or Puzzle.rotate_cw(b) == b:
		return false
	return current_mask(i) != b

# First tile that genuinely needs rotating. -1 if none (board already matches
# its home solution). BoardView adds a frontier preference on top of this.
func hint_cell() -> int:
	for i in range(base.size()):
		if is_hint_candidate(i):
			return i
	return -1

# Serialize to a compact dictionary (for save files / tests).
func to_dict() -> Dictionary:
	return {
		"w": width, "h": height,
		"base": Array(base), "rot": Array(rot),
		"active": Array(active), "locked": Array(locked),
	}

static func from_dict(d: Dictionary) -> Board:
	var b := Board.new(int(d["w"]), int(d["h"]))
	b.base = PackedInt32Array(d["base"])
	b.rot = PackedInt32Array(d["rot"])
	if d.has("active"):
		b.active = PackedByteArray(d["active"])
	if d.has("locked"):
		b.locked = PackedByteArray(d["locked"])
	return b
