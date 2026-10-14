class_name Generator
extends RefCounted

# Deterministic level generator + backtracking solver.
#
# Generation is solvable by construction: we build a connected graph over the
# grid (random spanning tree, optionally with a few extra loop edges), read off
# each tile's connector mask, then scramble rotations. The solved orientation
# always exists, so at least one solution is guaranteed.

# Build a solvable Board. `loop_chance` adds extra edges beyond the spanning
# tree (more branching / cycles => harder). Deterministic for a given seed.
# `holes` deactivates that many cells (validated to keep the board connected),
# `locked_count` fixes that many correct tiles the player cannot rotate.
static func generate(w: int, h: int, gen_seed: int, loop_chance: float = 0.0, holes: int = 0, locked_count: int = 0) -> Board:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed
	var b := Board.new(w, h)
	var n := w * h

	# --- carve holes first (keeps the active set connected) ---
	if holes > 0:
		_carve_holes(b, w, h, holes, rng)

	# --- randomized DFS spanning tree over ACTIVE cells only ---
	var visited := {}
	for i in range(n):
		if b.active[i] == 0:
			visited[i] = true  # holes are never visited / connected
	var start := _first_active(b, rng)
	var stack: Array[int] = [start]
	visited[start] = true
	while not stack.is_empty():
		var cur: int = stack[stack.size() - 1]
		@warning_ignore("integer_division")
		var row := cur / w
		var col := cur % w
		var opts: Array = []
		for dir in Puzzle.DIRS:
			var d: Vector2i = Puzzle.DELTA[dir]
			var nr := row + d.y
			var ncol := col + d.x
			if nr >= 0 and nr < h and ncol >= 0 and ncol < w:
				var ni := nr * w + ncol
				if not visited.has(ni):
					opts.append([dir, ni])
		if opts.is_empty():
			stack.pop_back()
			continue
		var pick: Array = opts[rng.randi_range(0, opts.size() - 1)]
		var dir2: int = pick[0]
		var ni2: int = pick[1]
		b.base[cur] = b.base[cur] | dir2
		b.base[ni2] = b.base[ni2] | Puzzle.opposite(dir2)
		visited[ni2] = true
		stack.append(ni2)

	# --- optional extra loop edges (skip holes) ---
	if loop_chance > 0.0:
		for row in range(h):
			for col in range(w):
				var i := row * w + col
				if b.active[i] == 0:
					continue
				for dir in [Puzzle.E, Puzzle.S]:
					var d: Vector2i = Puzzle.DELTA[dir]
					var nr := row + d.y
					var ncol := col + d.x
					if nr < h and ncol < w:
						var ni := nr * w + ncol
						if b.active[ni] == 1 and (b.base[i] & dir) == 0 and rng.randf() < loop_chance:
							b.base[i] = b.base[i] | dir
							b.base[ni] = b.base[ni] | Puzzle.opposite(dir)

	_scramble(b, rng)
	if locked_count > 0:
		_apply_locks(b, locked_count, rng)
	return b

static func _first_active(b: Board, rng: RandomNumberGenerator) -> int:
	var act: Array[int] = []
	for i in range(b.active.size()):
		if b.active[i] == 1:
			act.append(i)
	return act[rng.randi_range(0, act.size() - 1)]

# Deactivate `count` cells, each only if the active set stays fully connected.
static func _carve_holes(b: Board, w: int, h: int, count: int, rng: RandomNumberGenerator) -> void:
	var n := w * h
	var min_active: int = max(4, int(n * 0.45))
	var attempts := count * 10
	var made := 0
	while made < count and attempts > 0:
		attempts -= 1
		var c := rng.randi_range(0, n - 1)
		if b.active[c] == 0:
			continue
		b.active[c] = 0
		var active_count := 0
		for i in range(n):
			if b.active[i] == 1:
				active_count += 1
		if active_count < min_active or not _active_connected(b, w, h, active_count):
			b.active[c] = 1  # revert: would isolate or shrink too much
		else:
			made += 1

static func _active_connected(b: Board, w: int, h: int, active_count: int) -> bool:
	var start := -1
	for i in range(b.active.size()):
		if b.active[i] == 1:
			start = i
			break
	if start < 0:
		return false
	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		@warning_ignore("integer_division")
		var row := cur / w
		var col := cur % w
		for dir in Puzzle.DIRS:
			var d: Vector2i = Puzzle.DELTA[dir]
			var nr := row + d.y
			var ncol := col + d.x
			if nr >= 0 and nr < h and ncol >= 0 and ncol < w:
				var ni := nr * w + ncol
				if b.active[ni] == 1 and not seen.has(ni):
					seen[ni] = true
					stack.append(ni)
	return seen.size() == active_count

static func _movable_tiles(b: Board) -> Array[int]:
	var movable: Array[int] = []
	for i in range(b.base.size()):
		if b.active[i] == 0 or b.locked[i] == 1:
			continue
		var m := b.base[i]
		if m != 0 and m != Puzzle.ALL and _distinct_rotations(m).size() > 1:
			movable.append(i)
	return movable

static func _scramble(b: Board, rng: RandomNumberGenerator) -> void:
	for i in range(b.rot.size()):
		if b.active[i] == 1:
			b.rot[i] = rng.randi_range(0, 3)
	var movable := _movable_tiles(b)
	# guarantee the scramble is not already a solution and that the player has
	# real work to do: force at least one movable tile off its home orientation.
	if b.is_solved() or _all_home(b, movable):
		if not movable.is_empty():
			var t: int = movable[rng.randi_range(0, movable.size() - 1)]
			b.rot[t] = (b.rot[t] + 1 + rng.randi_range(0, 2)) % 4
			if b.is_solved():
				b.rot[t] = (b.rot[t] + 1) % 4

# Lock up to `count` correct (home-oriented) tiles as fixed anchors, always
# leaving enough movable tiles that the puzzle still requires work.
static func _apply_locks(b: Board, count: int, rng: RandomNumberGenerator) -> void:
	var movable := _movable_tiles(b)
	# keep at least ~40% (min 3) of movable tiles free to rotate
	var keep_free: int = max(3, int(movable.size() * 0.4))
	var lockable: int = max(0, movable.size() - keep_free)
	var to_lock: int = min(count, lockable)
	# shuffle movable deterministically
	for i in range(movable.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := movable[i]; movable[i] = movable[j]; movable[j] = tmp
	for k in range(to_lock):
		var idx := movable[k]
		b.rot[idx] = 0        # lock at its correct (home) orientation
		b.locked[idx] = 1
	# locking set some tiles to home; make sure it isn't now fully solved
	if b.is_solved():
		var free := _movable_tiles(b)
		if not free.is_empty():
			var t: int = free[rng.randi_range(0, free.size() - 1)]
			b.rot[t] = (b.rot[t] + 1) % 4

static func _all_home(b: Board, movable: Array[int]) -> bool:
	for i in movable:
		if b.rot[i] != 0:
			return false
	return true

# Distinct masks a tile can show across its 4 rotations.
static func _distinct_rotations(mask: int) -> Array[int]:
	var s: Array[int] = []
	var m := mask
	for _i in range(4):
		if not s.has(m):
			s.append(m)
		m = Puzzle.rotate_cw(m)
	return s

# ---------------------------------------------------------------------------
# Solver: count distinct solutions up to `cap` (row-major backtracking with
# border-pruned domains). Returns the number of solutions found (capped).
# ---------------------------------------------------------------------------
static func solve_count(b: Board, cap: int = 2) -> int:
	var w := b.width
	var h := b.height
	var n := w * h
	# domain[i] = distinct border-valid masks for cell i
	var domain: Array = []
	domain.resize(n)
	for row in range(h):
		for col in range(w):
			var i := row * w + col
			var valid: Array[int] = []
			for m in _distinct_rotations(b.base[i]):
				if _border_ok(m, row, col, w, h):
					valid.append(m)
			domain[i] = valid
	var assign := PackedInt32Array()
	assign.resize(n)
	var count := [0]
	_backtrack(0, w, h, domain, assign, count, cap)
	return count[0]

static func _border_ok(m: int, row: int, col: int, w: int, h: int) -> bool:
	if (m & Puzzle.N) and row == 0: return false
	if (m & Puzzle.S) and row == h - 1: return false
	if (m & Puzzle.W) and col == 0: return false
	if (m & Puzzle.E) and col == w - 1: return false
	return true

static func _backtrack(i: int, w: int, h: int, domain: Array, assign: PackedInt32Array, count: Array, cap: int) -> void:
	if count[0] >= cap:
		return
	var n := w * h
	if i == n:
		count[0] += 1
		return
	@warning_ignore("integer_division")
	var row := i / w
	var col := i % w
	for m in domain[i]:
		# consistency with already-assigned West and North neighbours
		var ok := true
		if col > 0:
			var wm := assign[i - 1]
			if bool(m & Puzzle.W) != bool(wm & Puzzle.E):
				ok = false
		if ok and row > 0:
			var nm := assign[i - w]
			if bool(m & Puzzle.N) != bool(nm & Puzzle.S):
				ok = false
		if ok:
			assign[i] = m
			_backtrack(i + 1, w, h, domain, assign, count, cap)
			if count[0] >= cap:
				return

# ---------------------------------------------------------------------------
# Move economy: the minimum number of CLOCKWISE taps to solve the board.
# Rotation is one-directional, so a tile at rotation r reaches a target
# orientation in (target - r) mod 4 taps. We branch-and-bound over all valid
# solutions to find the true optimum, capped by a node budget; the achievable
# home cost is both a fallback and an upper bound.
# ---------------------------------------------------------------------------

# Clockwise taps to turn a tile currently showing `cur_mask` into `target_mask`.
static func _cw_steps(cur_mask: int, target_mask: int) -> int:
	var m := cur_mask
	for s in range(4):
		if m == target_mask:
			return s
		m = Puzzle.rotate_cw(m)
	return 0

# Cost to rotate every movable tile back to its home orientation (achievable).
static func home_cw_cost(b: Board) -> int:
	var total := 0
	for i in range(b.rot.size()):
		if b.active[i] == 0 or b.locked[i] == 1:
			continue
		var base := b.base[i]
		if base == 0 or base == Puzzle.ALL:
			continue
		if _distinct_rotations(base).size() <= 1:
			continue
		total += _cw_steps(b.current_mask(i), base)  # home mask == base (rot 0)
	return total

# True minimum clockwise taps to reach ANY valid solution (capped). Falls back
# to the home cost if the search exceeds `node_cap`.
static func optimal_moves(b: Board, node_cap: int = 300000) -> int:
	var w := b.width
	var h := b.height
	var n := w * h
	var home := home_cw_cost(b)
	# domain[i] = array of [mask, cw_cost] for cell i
	var domain: Array = []
	domain.resize(n)
	for row in range(h):
		for col in range(w):
			var i := row * w + col
			var cur := b.current_mask(i)
			var opts: Array = []
			if b.locked[i] == 1:
				opts.append([cur, 0])  # locked tiles cannot move
			else:
				for m in _distinct_rotations(b.base[i]):
					if _border_hole_ok(b, m, row, col):
						opts.append([m, _cw_steps(cur, m)])
			# cheapest first helps branch-and-bound prune
			opts.sort_custom(func(a, c): return a[1] < c[1])
			domain[i] = opts
	var assign := PackedInt32Array()
	assign.resize(n)
	var best := [home]       # home is an achievable upper bound
	var nodes := [0]
	_bnb(0, w, h, domain, assign, 0, best, nodes, node_cap)
	return best[0]

static func _border_hole_ok(b: Board, m: int, row: int, col: int) -> bool:
	for dir in Puzzle.DIRS:
		if m & dir:
			var d: Vector2i = Puzzle.DELTA[dir]
			var nr := row + d.y
			var ncol := col + d.x
			if nr < 0 or nr >= b.height or ncol < 0 or ncol >= b.width:
				return false
			if b.active[nr * b.width + ncol] == 0:
				return false
	return true

static func _bnb(i: int, w: int, h: int, domain: Array, assign: PackedInt32Array, cost: int, best: Array, nodes: Array, node_cap: int) -> void:
	if cost >= best[0]:
		return
	nodes[0] += 1
	if nodes[0] > node_cap:
		return  # give up refining; best[] keeps the achievable home cost
	if i == w * h:
		best[0] = cost
		return
	@warning_ignore("integer_division")
	var row := i / w
	var col := i % w
	for opt in domain[i]:
		var m: int = opt[0]
		var ok := true
		if col > 0 and (bool(m & Puzzle.W) != bool(assign[i - 1] & Puzzle.E)):
			ok = false
		if ok and row > 0 and (bool(m & Puzzle.N) != bool(assign[i - w] & Puzzle.S)):
			ok = false
		if ok:
			assign[i] = m
			_bnb(i + 1, w, h, domain, assign, cost + int(opt[1]), best, nodes, node_cap)
