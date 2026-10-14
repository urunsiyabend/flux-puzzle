extends SceneTree

# Headless test runner:
#   godot --headless --path <project> -s res://tests/run_tests.gd
# Exits with code 0 on success, 1 on any failure.

var _pass := 0
var _fail := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		push_error("FAIL: " + msg)
		print("  [FAIL] ", msg)

func _initialize() -> void:
	print("== FLUX test suite ==")
	_test_rotation()
	_test_win_conditions()
	_test_invalid_and_offboard()
	_test_generator_solvable()
	_test_solver()
	_test_holes()
	_test_locked()
	_test_move_economy()
	_test_hint()
	_test_worlds()
	_test_levels()
	_test_progression()
	_test_rules()
	_test_proto_net()
	_test_proto_lamps()
	_test_proto_linked()
	print("== done: %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _test_rotation() -> void:
	_ok(Puzzle.rotate_cw(Puzzle.N) == Puzzle.E, "N rotates to E")
	_ok(Puzzle.rotate_cw(Puzzle.E) == Puzzle.S, "E rotates to S")
	_ok(Puzzle.rotate_cw(Puzzle.S) == Puzzle.W, "S rotates to W")
	_ok(Puzzle.rotate_cw(Puzzle.W) == Puzzle.N, "W rotates to N")
	_ok(Puzzle.rotate(Puzzle.N | Puzzle.E, 4) == (Puzzle.N | Puzzle.E), "4 rotations identity")
	_ok(Puzzle.opposite(Puzzle.N) == Puzzle.S, "opposite N is S")
	_ok(Puzzle.opposite(Puzzle.E) == Puzzle.W, "opposite E is W")
	_ok(Puzzle.popcount(Puzzle.ALL) == 4, "popcount full is 4")
	_ok(Puzzle.popcount(0) == 0, "popcount empty is 0")
	# straight piece has only 2 distinct rotations
	_ok(Puzzle.rotate(Puzzle.N | Puzzle.S, 2) == (Puzzle.N | Puzzle.S), "straight is 2-periodic")

func _test_win_conditions() -> void:
	# 1x2 board: left cell connects E, right cell connects W -> solved
	var b := Board.new(2, 1)
	b.base[0] = Puzzle.E
	b.base[1] = Puzzle.W
	_ok(b.is_solved(), "matched 1x2 is solved")
	_ok(b.unmatched_count() == 0, "matched 1x2 has 0 unmatched")
	# rotate left cell -> connector no longer faces right -> not solved
	b.rot[0] = 1  # E -> S (points off board)
	_ok(not b.is_solved(), "rotated 1x2 not solved")
	_ok(b.unmatched_count() > 0, "rotated 1x2 has unmatched")

func _test_invalid_and_offboard() -> void:
	# single cell with a connector pointing anywhere -> always off board -> never solved
	var b := Board.new(1, 1)
	b.base[0] = Puzzle.N
	var any_solved := false
	for r in range(4):
		b.rot[0] = r
		if b.is_solved():
			any_solved = true
	_ok(not any_solved, "lone connector can never be solved (off-board)")
	# empty cell (mask 0) is trivially fine
	var e := Board.new(1, 1)
	e.base[0] = 0
	_ok(e.is_solved(), "empty single cell is solved")

func _test_generator_solvable() -> void:
	var sizes := [[3, 3], [4, 5], [5, 6], [7, 9]]
	for sz in sizes:
		for s in range(4):
			var board := Generator.generate(sz[0], sz[1], 1000 + s * 13, 0.1)
			# home orientation (all rot 0) must be a valid solution
			var home := Board.from_dict(board.to_dict())
			for i in range(home.rot.size()):
				home.rot[i] = 0
			_ok(home.is_solved(), "home orientation solves %dx%d seed %d" % [sz[0], sz[1], s])
			# no connector in the solved masks points off the board
			_ok(_no_offboard(home), "solved masks stay on board %dx%d" % [sz[0], sz[1]])

func _no_offboard(b: Board) -> bool:
	for row in range(b.height):
		for col in range(b.width):
			var m := b.base[row * b.width + col]
			if (m & Puzzle.N) and row == 0: return false
			if (m & Puzzle.S) and row == b.height - 1: return false
			if (m & Puzzle.W) and col == 0: return false
			if (m & Puzzle.E) and col == b.width - 1: return false
	return true

func _home(b: Board) -> Board:
	var home := Board.from_dict(b.to_dict())
	for i in range(home.rot.size()):
		if home.active[i] == 1:
			home.rot[i] = 0
	return home

func _active_count(b: Board) -> int:
	var c := 0
	for i in range(b.active.size()):
		if b.active[i] == 1:
			c += 1
	return c

func _connected(b: Board) -> bool:
	var start := -1
	for i in range(b.active.size()):
		if b.active[i] == 1:
			start = i; break
	if start < 0:
		return false
	var seen := {start: true}
	var st: Array[int] = [start]
	while not st.is_empty():
		var cur: int = st.pop_back()
		var row := cur / b.width
		var col := cur % b.width
		for dir in Puzzle.DIRS:
			var d: Vector2i = Puzzle.DELTA[dir]
			var nr := row + d.y
			var ncol := col + d.x
			if nr >= 0 and nr < b.height and ncol >= 0 and ncol < b.width:
				var ni := nr * b.width + ncol
				if b.active[ni] == 1 and not seen.has(ni):
					seen[ni] = true; st.append(ni)
	return seen.size() == _active_count(b)

func _no_connectors_into_holes_or_edge(b: Board) -> bool:
	for row in range(b.height):
		for col in range(b.width):
			var i := row * b.width + col
			if b.active[i] == 0:
				continue
			var m := b.base[i]
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

func _test_holes() -> void:
	for s in range(5):
		var b := Generator.generate(6, 6, 700 + s, 0.1, 6, 0)
		_ok(_active_count(b) < 36, "holes actually removed cells (seed %d)" % s)
		_ok(_connected(b), "active set stays connected with holes (seed %d)" % s)
		_ok(_home(b).is_solved(), "holed board solves at home (seed %d)" % s)
		_ok(_no_connectors_into_holes_or_edge(b), "no connectors point into holes/edge (seed %d)" % s)

func _test_locked() -> void:
	for s in range(5):
		var b := Generator.generate(6, 6, 800 + s, 0.08, 0, 3)
		var locked_count := 0
		var free_count := 0
		for i in range(b.locked.size()):
			if b.locked[i] == 1:
				locked_count += 1
				_ok(b.rot[i] == 0, "locked tile is at home orientation")
		# count movable unlocked tiles remaining
		for i in range(b.base.size()):
			if b.active[i] == 1 and b.locked[i] == 0 and b.base[i] != 0 and b.base[i] != Puzzle.ALL:
				if Generator._distinct_rotations(b.base[i]).size() > 1:
					free_count += 1
		_ok(locked_count >= 1, "some tiles locked (seed %d)" % s)
		_ok(free_count >= 1, "playable tiles remain after locking (seed %d)" % s)
		_ok(_home(b).is_solved(), "locked board solves at home (seed %d)" % s)

func _test_move_economy() -> void:
	# an already-solved board needs 0 taps
	var solved := Board.new(2, 1)
	solved.base[0] = Puzzle.E
	solved.base[1] = Puzzle.W
	_ok(Generator.optimal_moves(solved) == 0, "solved board optimum is 0 taps")
	_ok(Generator.home_cw_cost(solved) == 0, "solved board home cost is 0")

	# 2x1 line with the left tile turned 2 clockwise steps off: only valid
	# orientation is E, so it takes exactly 2 clockwise taps to fix.
	var b := Board.new(2, 1)
	b.base[0] = Puzzle.E
	b.base[1] = Puzzle.W
	b.rot[0] = 2
	_ok(Generator.optimal_moves(b) == 2, "clockwise optimum counts up-to-3 correctly")

	# optimum is always achievable and never worse than the home cost
	for s in range(5):
		var g := Generator.generate(4, 4, 900 + s, 0.08)
		var opt := Generator.optimal_moves(g)
		var home := Generator.home_cw_cost(g)
		_ok(opt >= 0, "optimum non-negative (seed %d)" % s)
		_ok(opt <= home, "optimum <= achievable home cost (seed %d)" % s)
		# solving the generated scramble by its own moves is possible in `opt`
		_ok(_home(g).is_solved(), "home is a valid solution (seed %d)" % s)

func _test_hint() -> void:
	# 3x1 line, all at home -> solved -> no hint
	var b := Board.new(3, 1)
	b.base[0] = Puzzle.E
	b.base[1] = Puzzle.W | Puzzle.E
	b.base[2] = Puzzle.W
	_ok(b.hint_cell() == -1, "no hint when already at home solution")
	_ok(not b.is_hint_candidate(0), "a home-oriented tile is not a hint target")
	# turn the last tile off home -> it becomes the hint, others do not
	b.rot[2] = 1
	_ok(b.is_hint_candidate(2), "an off-home tile is a hint target")
	_ok(not b.is_hint_candidate(0), "a correct tile is never hinted")
	_ok(b.hint_cell() == 2, "hint points at the tile that needs rotating")
	# a straight piece at rotation 2 shows the same mask as home -> not a target
	b.rot[2] = 0
	b.rot[1] = 2
	_ok(not b.is_hint_candidate(1), "2-periodic tile showing home mask is not hinted")
	_ok(b.hint_cell() == -1, "straight-at-180 counts as solved, no false hint")

func _test_worlds() -> void:
	var L = preload("res://autoload/Levels.gd").new()
	L._build_catalogue()
	_ok(L.world_of(0) == 0, "level 1 is world 0")
	_ok(L.world_of(6) == 1, "level 7 is world 1")
	_ok(L.world_of(23) == 3, "level 24 is world 3")
	_ok(L.WORLD_NAMES.size() == 4, "four world names")
	_ok(L.WORLD_INTROS.size() == L.WORLD_NAMES.size(), "every world has a one-line intro")
	_ok(L.is_world_start(0) and L.is_world_start(6), "levels 1 and 7 open a world")
	_ok(not L.is_world_start(5), "level 6 does not open a world")
	# every catalogue level still solvable with its mechanics
	var all_ok := true
	for i in range(L.count()):
		if not _home(L.get_board(i)).is_solved():
			all_ok = false
	_ok(all_ok, "every mechanic-laden level is solvable")

func _test_solver() -> void:
	# solver must find at least one solution for generated boards
	for s in range(5):
		var board := Generator.generate(4, 4, 500 + s, 0.08)
		var c := Generator.solve_count(board, 1)
		_ok(c >= 1, "solver finds a solution (4x4 seed %d)" % s)
	# tiny deterministic board: 2x1 straight -> exactly one distinct solution
	var line := Board.new(2, 1)
	line.base[0] = Puzzle.E
	line.base[1] = Puzzle.W
	_ok(Generator.solve_count(line, 5) == 1, "2x1 line has a unique solution")

func _test_levels() -> void:
	var L = preload("res://autoload/Levels.gd").new()
	L._build_catalogue()
	_ok(L.count() >= 20, "at least 20 levels (%d)" % L.count())
	# difficulty should not decrease across the catalogue
	var ok_curve := true
	var prev := 0
	for i in range(L.count()):
		if L.tier(i) < prev:
			ok_curve = false
		prev = L.tier(i)
	_ok(ok_curve, "difficulty tier is non-decreasing")
	# every level builds a solvable board
	var all_solvable := true
	for i in range(L.count()):
		var b := L.get_board(i)
		var home := Board.from_dict(b.to_dict())
		for k in range(home.rot.size()):
			home.rot[k] = 0
		if not home.is_solved():
			all_solvable = false
	_ok(all_solvable, "every catalogue level is solvable")

func _test_progression() -> void:
	var S = preload("res://autoload/Save.gd").new()
	S.autosave = false
	_ok(S.is_unlocked(0), "level 0 unlocked by default")
	_ok(not S.is_unlocked(1), "level 1 locked by default")
	S.complete_level(0, 12)
	_ok(S.is_unlocked(1), "completing 0 unlocks 1")
	_ok(S.best_moves(0) == 12, "best moves recorded")
	S.complete_level(0, 20)
	_ok(S.best_moves(0) == 12, "best moves keeps the minimum")
	S.complete_level(0, 8)
	_ok(S.best_moves(0) == 8, "best moves updates to a better score")

func _test_rules() -> void:
	# wrap: stepping off an edge lands on the opposite side
	var b := Board.new(3, 3)
	_ok(b.step(0, Puzzle.W) == -1, "bounded board: no neighbour off the edge")
	b.wrap = true
	_ok(b.step(0, Puzzle.W) == 2, "wrap: west of col 0 is the last column")
	_ok(b.step(0, Puzzle.N) == 6, "wrap: north of row 0 is the last row")
	# NET rule: a closed 2x2 ring is matched but not a valid network
	var ring := Board.new(2, 2)
	ring.base[0] = Puzzle.E | Puzzle.S
	ring.base[1] = Puzzle.W | Puzzle.S
	ring.base[2] = Puzzle.N | Puzzle.E
	ring.base[3] = Puzzle.N | Puzzle.W
	_ok(ring.is_solved(), "ring satisfies the classic matching rule")
	ring.rule = Board.RULE_NET
	_ok(not ring.is_solved(), "ring fails the NET rule (closed loop)")
	var loops := ring.loop_cells()
	_ok(loops[0] == 1 and loops[3] == 1, "loop cells are reported for feedback")
	# breaking the ring into a path makes a valid tree
	ring.base[1] = Puzzle.W
	ring.base[3] = Puzzle.W
	ring.base[2] = Puzzle.N | Puzzle.E
	_ok(ring.is_solved(), "loop-free connected path passes the NET rule")
	_ok(ring.loop_cells()[0] == 0, "no loop cells on a tree")

func _test_proto_net() -> void:
	var L = preload("res://autoload/Levels.gd").new()
	L._build_catalogue()
	for lvl in range(L.proto_count("net")):
		var b: Board = L.get_proto_board("net", lvl)
		_ok(b.wrap and b.rule == Board.RULE_NET, "net %d: wrapping NET board" % [lvl + 1])
		_ok(not b.is_solved(), "net %d: starts unsolved" % [lvl + 1])
		_ok(_home(b).is_solved(), "net %d: home orientation solves it" % [lvl + 1])
		_ok(Generator.count_solutions(b, 2) == 1, "net %d: unique solution" % [lvl + 1])
		_ok(Generator.local_solved_ratio(b) < 1.0, "net %d: local deduction alone cannot finish" % [lvl + 1])

func _test_proto_lamps() -> void:
	var L = preload("res://autoload/Levels.gd").new()
	L._build_catalogue()
	for lvl in range(L.proto_count("lamps")):
		var b: Board = L.get_proto_board("lamps", lvl)
		var lamps := 0
		var decoys := 0
		for i in range(b.lamp.size()):
			lamps += b.lamp[i]
			decoys += 1 - b.need[i]
		_ok(lamps >= 1, "lamps %d: has lamps" % [lvl + 1])
		_ok(decoys > 0, "lamps %d: has decoy tiles" % [lvl + 1])
		_ok(not b.is_solved(), "lamps %d: starts unsolved" % [lvl + 1])
		var h := Board.from_dict(b.to_dict())
		for i in range(h.rot.size()):
			if h.need[i] == 1:
				h.rot[i] = 0
		_ok(h.is_solved(), "lamps %d: the route tiles at home power every lamp" % [lvl + 1])

func _test_proto_linked() -> void:
	var L = preload("res://autoload/Levels.gd").new()
	L._build_catalogue()
	for lvl in range(L.proto_count("linked")):
		var b: Board = L.get_proto_board("linked", lvl)
		_ok(b.has_links(), "linked %d: has chained tiles" % [lvl + 1])
		var sym := true
		for i in range(b.links.size()):
			for j in b.links[i]:
				if not b.links[j].has(i):
					sym = false
		_ok(sym, "linked %d: links are symmetric" % [lvl + 1])
		_ok(not b.is_solved(), "linked %d: starts unsolved" % [lvl + 1])
		# tap/untap are exact inverses
		var before := b.rot.duplicate()
		b.tap(0)
		b.untap(0)
		_ok(b.rot == before, "linked %d: untap restores the board" % [lvl + 1])
		# replaying the inverse taps solves it, and the hint follows that plan
		var guard := 0
		while b.hint_cell() >= 0 and guard < 400:
			b.tap(b.hint_cell())
			guard += 1
		_ok(b.is_solved(), "linked %d: following hints solves the board" % [lvl + 1])
