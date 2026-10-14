class_name Board
extends RefCounted

# A concrete puzzle instance: solved connector masks plus the player's current
# rotation of each tile. Pure data + rules, no rendering.

# Win rules (prototype modes share one board model):
const RULE_MATCH := 0   # every connector mutually matched (classic)
const RULE_NET := 1     # matched AND one connected network with no closed loops
const RULE_LAMPS := 2   # every lamp powered from the source; open ends allowed

var width: int
var height: int
var base: PackedInt32Array      # solved mask per cell
var rot: PackedInt32Array       # current rotation steps (0..3) per cell
var active: PackedByteArray     # 1 = real tile, 0 = hole (not part of the board)
var locked: PackedByteArray     # 1 = fixed tile the player cannot rotate

var rule := RULE_MATCH
var wrap := false               # edges wrap around to the opposite side (torus)
var source := -1                # energy source cell (-1 = let the view choose)
var lamp: PackedByteArray       # 1 = lamp that must be powered (RULE_LAMPS)
var need: PackedByteArray       # 1 = tile is part of the solution (0 = decoy)
var links: Array = []           # per cell: Array of cells that rotate with it
var gen_taps: PackedInt32Array  # scramble taps per cell (linked boards only)
var taps: PackedInt32Array      # player taps per cell

func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h
	base = PackedInt32Array()
	rot = PackedInt32Array()
	active = PackedByteArray()
	locked = PackedByteArray()
	lamp = PackedByteArray()
	need = PackedByteArray()
	gen_taps = PackedInt32Array()
	taps = PackedInt32Array()
	base.resize(w * h)
	rot.resize(w * h)
	active.resize(w * h)
	locked.resize(w * h)
	lamp.resize(w * h)
	need.resize(w * h)
	gen_taps.resize(w * h)
	taps.resize(w * h)
	links = []
	for i in range(w * h):
		active[i] = 1
		need[i] = 1
		links.append([])

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

# Index of the neighbour of cell i in `dir`, honouring wrap. -1 = off the board.
func step(i: int, dir: int) -> int:
	@warning_ignore("integer_division")
	var row := i / width
	var col := i % width
	var d: Vector2i = Puzzle.DELTA[dir]
	var nr := row + d.y
	var nc := col + d.x
	if wrap:
		nr = posmod(nr, height)
		nc = posmod(nc, width)
	elif not in_bounds(nr, nc):
		return -1
	return idx(nr, nc)

# Rotate one tile clockwise by one quarter turn.
func rotate_cell(i: int) -> void:
	rot[i] = (rot[i] + 1) % 4

func has_links() -> bool:
	for l in links:
		if not l.is_empty():
			return true
	return false

# A player tap: rotates the tile and every tile linked to it. Returns the
# cells that turned (for animation).
func tap(i: int) -> Array[int]:
	var turned: Array[int] = [i]
	for j in links[i]:
		if active[j] == 1 and locked[j] == 0:
			turned.append(j)
	for j in turned:
		rotate_cell(j)
	taps[i] += 1
	return turned

# Exact inverse of tap(i).
func untap(i: int) -> Array[int]:
	var turned: Array[int] = [i]
	for j in links[i]:
		if active[j] == 1 and locked[j] == 0:
			turned.append(j)
	for j in turned:
		rot[j] = (rot[j] + 3) % 4
	taps[i] -= 1
	return turned

func is_solved() -> bool:
	match rule:
		RULE_LAMPS:
			return _lamps_lit()
		RULE_NET:
			return _all_matched() and _is_tree()
	return _all_matched()

# True when every connector on every tile is mutually matched and none point
# off the board. Order-independent; alternate symmetric solutions also pass.
func _all_matched() -> bool:
	for i in range(base.size()):
		var m := current_mask(i)
		for dir in Puzzle.DIRS:
			if m & dir:
				var ni := step(i, dir)
				if ni < 0 or (current_mask(ni) & Puzzle.opposite(dir)) == 0:
					return false
	return true

# Count of connectors that are NOT satisfied right now (for live feedback).
func unmatched_count() -> int:
	var bad := 0
	for i in range(base.size()):
		var m := current_mask(i)
		for dir in Puzzle.DIRS:
			if m & dir:
				var ni := step(i, dir)
				if ni < 0 or (current_mask(ni) & Puzzle.opposite(dir)) == 0:
					bad += 1
	return bad

# Cells reached by energy flowing from `from` through mutually matched connectors.
func energized(from: int) -> PackedByteArray:
	var on := PackedByteArray()
	on.resize(base.size())
	if from < 0:
		return on
	var stack: Array[int] = [from]
	on[from] = 1
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		var m := current_mask(cur)
		for dir in Puzzle.DIRS:
			if m & dir:
				var ni := step(cur, dir)
				if ni >= 0 and on[ni] == 0 and (current_mask(ni) & Puzzle.opposite(dir)) != 0:
					on[ni] = 1
					stack.append(ni)
	return on

func _lamps_lit() -> bool:
	var on := energized(source)
	for i in range(lamp.size()):
		if lamp[i] == 1 and on[i] == 0:
			return false
	return true

# One network that reaches every tile, with exactly n-1 links (no loops).
# Assumes all connectors are matched.
func _is_tree() -> bool:
	var tiles := 0
	var start := -1
	var ends := 0
	for i in range(base.size()):
		if active[i] == 1 and base[i] != 0:
			tiles += 1
			start = i
			ends += Puzzle.popcount(base[i])
	if tiles == 0:
		return true
	var on := energized(start)
	var reached := 0
	for v in on:
		reached += v
	@warning_ignore("integer_division")
	return reached == tiles and ends / 2 == tiles - 1

# Cells that currently sit on a closed loop of matched connectors (for the
# NET rule's error feedback). Leaves are peeled off until only cycles remain.
func loop_cells() -> PackedByteArray:
	var n := base.size()
	var deg := PackedInt32Array()
	deg.resize(n)
	for i in range(n):
		var m := current_mask(i)
		for dir in Puzzle.DIRS:
			if m & dir:
				var ni := step(i, dir)
				if ni >= 0 and (current_mask(ni) & Puzzle.opposite(dir)) != 0:
					deg[i] += 1
	var gone := PackedByteArray()
	gone.resize(n)
	var stack: Array[int] = []
	for i in range(n):
		if deg[i] <= 1:
			stack.append(i)
	while not stack.is_empty():
		var c: int = stack.pop_back()
		if gone[c] == 1:
			continue
		gone[c] = 1
		var m := current_mask(c)
		for dir in Puzzle.DIRS:
			if m & dir:
				var ni := step(c, dir)
				if ni >= 0 and gone[ni] == 0 and (current_mask(ni) & Puzzle.opposite(dir)) != 0:
					deg[ni] -= 1
					if deg[ni] <= 1:
						stack.append(ni)
	var out := PackedByteArray()
	out.resize(n)
	for i in range(n):
		out[i] = 1 - gone[i]
	return out

# True when a tile is a valid hint target. Linked boards track taps (the
# scramble is undone by tapping each cell back); others compare against the
# home orientation, ignoring decoys and straights already showing home.
func is_hint_candidate(i: int) -> bool:
	if active[i] == 0 or locked[i] == 1 or need[i] == 0:
		return false
	if has_links():
		return posmod(-gen_taps[i] - taps[i], 4) != 0
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
		"rule": rule, "wrap": wrap, "source": source,
		"lamp": Array(lamp), "need": Array(need), "links": links.duplicate(true),
		"gen_taps": Array(gen_taps), "taps": Array(taps),
	}

static func from_dict(d: Dictionary) -> Board:
	var b := Board.new(int(d["w"]), int(d["h"]))
	b.base = PackedInt32Array(d["base"])
	b.rot = PackedInt32Array(d["rot"])
	if d.has("active"):
		b.active = PackedByteArray(d["active"])
	if d.has("locked"):
		b.locked = PackedByteArray(d["locked"])
	if d.has("rule"):
		b.rule = int(d["rule"])
		b.wrap = bool(d["wrap"])
		b.source = int(d["source"])
		b.lamp = PackedByteArray(d["lamp"])
		b.need = PackedByteArray(d["need"])
		b.links = d["links"].duplicate(true)
		b.gen_taps = PackedInt32Array(d["gen_taps"])
		b.taps = PackedInt32Array(d["taps"])
	return b
