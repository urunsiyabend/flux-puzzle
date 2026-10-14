class_name BoardView
extends Node2D

# Renders a Board and handles touch/mouse rotation. All tiles are drawn in one
# _draw() pass for performance; rotations animate via a per-cell angle lerp.

signal moved(move_count: int)
signal solved()

var board: Board
var cell := 100.0
var origin := Vector2.ZERO
var source_cell := -1

var _display_angle: PackedFloat32Array   # animated, radians
var _target_angle: PackedFloat32Array
var _energized: PackedByteArray
var _loops: PackedByteArray                 # NET rule: tiles sitting on a closed loop
var _animating := false
var _interactive := true

var move_count := 0
var _undo: Array = []                      # tapped cells, newest last
var _hint_cell := -1
var _hint_timer := 0.0
var _win_pulse := 0.0
var _solved := false

var _flash: PackedFloat32Array              # per-tile brightness pop on rotate
var _trauma := 0.0                          # screen-shake energy (0..1)
var _shake_t := 0.0
var _reject_cell := -1                      # locked tile tapped (wiggle feedback)
var _reject_t := 0.0

const ROT_SPEED := 14.0                     # radians/sec approach
const SHAKE_DECAY := 1.6
const SHAKE_MAX := Vector2(10, 14)

func setup(b: Board, rect: Rect2) -> void:
	board = b
	var n := b.width * b.height
	_display_angle = PackedFloat32Array()
	_target_angle = PackedFloat32Array()
	_flash = PackedFloat32Array()
	_display_angle.resize(n)
	_target_angle.resize(n)
	_flash.resize(n)
	for i in range(n):
		_display_angle[i] = b.rot[i] * PI / 2.0
		_target_angle[i] = _display_angle[i]
	move_count = 0
	_undo.clear()
	_solved = false
	_win_pulse = 0.0
	_hint_cell = -1
	_trauma = 0.0
	_reject_cell = -1
	_reject_t = 0.0
	position = Vector2.ZERO
	if b.source >= 0:
		source_cell = b.source
	else:
		_choose_source()
	_fit(rect)
	_recompute_energy()
	queue_redraw()

func refit(rect: Rect2) -> void:
	_fit(rect)
	queue_redraw()

func _fit(rect: Rect2) -> void:
	var cw := rect.size.x / board.width
	var ch := rect.size.y / board.height
	cell = min(cw, ch)
	var gw := cell * board.width
	var gh := cell * board.height
	origin = rect.position + Vector2((rect.size.x - gw) * 0.5, (rect.size.y - gh) * 0.5)

func _choose_source() -> void:
	var best := -1
	var best_score := -1.0
	var cx := (board.width - 1) / 2.0
	var cy := (board.height - 1) / 2.0
	for row in range(board.height):
		for col in range(board.width):
			var i := board.idx(row, col)
			if board.base[i] == 0:
				continue
			var pc := Puzzle.popcount(board.base[i])
			var dist: float = abs(col - cx) + abs(row - cy)
			var score: float = pc * 10.0 - dist
			if score > best_score:
				best_score = score
				best = i
	source_cell = best

func set_interactive(v: bool) -> void:
	_interactive = v

# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _interactive or _solved:
		return
	# Only handle touch. The project enables emulate_touch_from_mouse, so a
	# desktop mouse click arrives here as a touch too; handling the mouse event
	# as well would rotate the tile twice (180 deg) per tap.
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return
	var local := to_local(pos)
	var col := int(floor((local.x - origin.x) / cell))
	var row := int(floor((local.y - origin.y) / cell))
	if not board.in_bounds(row, col):
		return
	var i := board.idx(row, col)
	if board.base[i] == 0 or board.is_hole(i):
		return
	if board.is_locked(i):
		_reject_locked(i)
		get_viewport().set_input_as_handled()
		return
	_rotate(i, true)
	get_viewport().set_input_as_handled()

func _reject_locked(i: int) -> void:
	_reject_cell = i
	_reject_t = 0.4
	Audio.play("error")
	queue_redraw()

func _rotate(i: int, user: bool) -> void:
	if user:
		_undo.append(i)
		move_count += 1
	for j in board.tap(i):
		_target_angle[j] += PI / 2.0
		_flash[j] = 1.0
	_animating = true
	Audio.play("rotate")
	_recompute_energy()
	if user:
		moved.emit(move_count)
	if board.is_solved():
		_win()
	queue_redraw()

func undo() -> void:
	if _undo.is_empty() or _solved:
		return
	var i: int = _undo.pop_back()
	for j in board.untap(i):
		_target_angle[j] -= PI / 2.0
	move_count = max(0, move_count - 1)
	_animating = true
	Audio.play("tap")
	_recompute_energy()
	moved.emit(move_count)
	queue_redraw()

func request_hint() -> void:
	if _solved:
		return
	# all tiles that genuinely need rotating (current orientation != home)
	var cands: Array[int] = []
	for i in range(board.base.size()):
		if board.is_hint_candidate(i):
			cands.append(i)
	if cands.is_empty():
		return
	# prefer one touching the already-energised network, so fixing it visibly
	# extends the live circuit (a frontier move, the most useful hint)
	var pick := -1
	for i in cands:
		for dir in Puzzle.DIRS:
			var ni := board.step(i, dir)
			if ni >= 0 and _energized[ni] == 1:
				pick = i
				break
		if pick >= 0:
			break
	if pick < 0:
		pick = cands[0]
	_hint_cell = pick
	_hint_timer = 2.0
	Audio.play("hint")
	queue_redraw()

func _win() -> void:
	_solved = true
	_win_pulse = 0.0
	_trauma = 0.7
	Audio.play("win")
	# snap angles to a clean state
	for i in range(board.rot.size()):
		_target_angle[i] = board.rot[i] * PI / 2.0
	_recompute_energy()
	solved.emit()

# --- energy flood from source through mutually-matched connectors ----------

func _recompute_energy() -> void:
	_energized = board.energized(source_cell)
	if board.rule == Board.RULE_NET:
		_loops = board.loop_cells()
	else:
		_loops = PackedByteArray()
		_loops.resize(board.base.size())

# --- animation -------------------------------------------------------------

func _process(delta: float) -> void:
	if _animating:
		var still := false
		for i in range(_display_angle.size()):
			var a := _display_angle[i]
			var t := _target_angle[i]
			if abs(a - t) > 0.001:
				_display_angle[i] = lerp(a, t, clampf(ROT_SPEED * delta, 0.0, 1.0))
				still = true
			else:
				_display_angle[i] = t
		_animating = still
		queue_redraw()
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint_cell = -1
		queue_redraw()
	if _reject_t > 0.0:
		_reject_t = maxf(_reject_t - delta, 0.0)
		if _reject_t <= 0.0:
			_reject_cell = -1
		queue_redraw()
	# per-tile flash decay
	var flashing := false
	for i in range(_flash.size()):
		if _flash[i] > 0.0:
			_flash[i] = maxf(_flash[i] - delta * 4.0, 0.0)
			flashing = true
	if flashing:
		queue_redraw()
	# screen shake via decaying trauma (quadratic), applied to this node only
	if _trauma > 0.0:
		_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
		_shake_t += delta * 32.0
		var s := _trauma * _trauma
		position = Vector2(SHAKE_MAX.x * s * sin(_shake_t * 1.7), SHAKE_MAX.y * s * sin(_shake_t * 2.3))
		if _trauma <= 0.0:
			position = Vector2.ZERO
		queue_redraw()
	if _solved:
		_win_pulse += delta
		queue_redraw()

# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if board.wrap:
		_draw_wrap_frame()
	for row in range(board.height):
		for col in range(board.width):
			_draw_cell(row, col)
	_draw_links()

# Wrapping boards get a dashed frame so it reads as "the edges continue".
func _draw_wrap_frame() -> void:
	var r := Rect2(origin, Vector2(cell * board.width, cell * board.height)).grow(cell * 0.04)
	var col := Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.45)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in range(4):
		draw_dashed_line(corners[k], corners[(k + 1) % 4], col, 4.0, cell * 0.12)

# Chained tiles: a warm rivet across the edge they share.
func _draw_links() -> void:
	var warm := Palette.ACCENT_WARM
	for i in range(board.links.size()):
		for j in board.links[i]:
			if j < i:
				continue
			@warning_ignore("integer_division")
			var a := origin + Vector2((i % board.width) + 0.5, (i / board.width) + 0.5) * cell
			@warning_ignore("integer_division")
			var b := origin + Vector2((j % board.width) + 0.5, (j / board.width) + 0.5) * cell
			var mid := (a + b) * 0.5
			var along := (b - a).normalized()
			var across := Vector2(-along.y, along.x)
			draw_line(mid - along * cell * 0.16, mid + along * cell * 0.16, warm, cell * 0.09, true)
			draw_circle(mid - along * cell * 0.16, cell * 0.06, warm)
			draw_circle(mid + along * cell * 0.16, cell * 0.06, warm)
			draw_line(mid - across * cell * 0.02, mid + across * cell * 0.02, Palette.BG_TILE, cell * 0.03)

func _draw_cell(row: int, col: int) -> void:
	var i := board.idx(row, col)
	# holes are not drawn at all — the board reads as an irregular shape
	if board.is_hole(i):
		return
	var m := board.base[i]
	var rejecting := i == _reject_cell and _reject_t > 0.0
	var wig := 0.0
	if rejecting:
		wig = sin(_reject_t * 70.0) * cell * 0.07 * (_reject_t / 0.4)
	var tl := origin + Vector2(col * cell + wig, row * cell)
	var center := tl + Vector2(cell, cell) * 0.5
	var pad := cell * 0.06
	var inner := Rect2(tl + Vector2(pad, pad), Vector2(cell - 2 * pad, cell - 2 * pad))

	var is_locked := board.is_locked(i)
	var in_loop := _loops.size() > i and _loops[i] == 1
	var linked: bool = not board.links[i].is_empty()

	# tile background
	var bg := Palette.BG_TILE
	if is_locked:
		bg = bg.lerp(Palette.ACCENT, 0.1)
	if linked:
		bg = bg.lerp(Palette.ACCENT_WARM, 0.08)
	if in_loop and not _solved:
		bg = bg.lerp(Palette.DANGER, 0.22)
	if rejecting:
		bg = bg.lerp(Palette.DANGER, 0.3)
	draw_rect(inner, bg, true)
	var border_col := Palette.GRID_LINE
	if is_locked:
		border_col = Palette.DANGER if rejecting else Palette.ACCENT.darkened(0.3)
	_draw_rect_outline(inner, border_col, 3.0 if is_locked else 2.0)

	if m == 0:
		return

	var on := _energized[i] == 1
	var wire := Palette.WIRE_ON if on else Palette.WIRE_OFF
	if i < _flash.size() and _flash[i] > 0.0:
		wire = wire.lerp(Palette.WIRE_GLOW, _flash[i] * 0.7)
	var glow := Palette.WIRE_GLOW
	var ang := _display_angle[i]
	var half := cell * 0.5

	# connectors: rotate the base directions by the animated angle
	for dir in Puzzle.DIRS:
		if m & dir:
			var base_vec := _dir_vector(dir)
			var v := base_vec.rotated(ang)
			var endp := center + v * (half - pad)
			if on:
				draw_line(center, endp, glow, cell * 0.22, true)
			draw_line(center, endp, wire, cell * 0.11, true)
			# endpoint lamp for terminals
			if Puzzle.popcount(m) == 1:
				draw_circle(endp, cell * 0.11, wire)
				if on:
					draw_circle(endp, cell * 0.16, Color(glow.r, glow.g, glow.b, 0.35))

	# center hub
	var hub := wire
	if i == source_cell:
		draw_circle(center, cell * 0.2, Palette.ACCENT_WARM)
		draw_circle(center, cell * 0.12, Palette.BG_TILE)
		draw_circle(center, cell * 0.07, Palette.ACCENT_WARM)
	else:
		draw_circle(center, cell * 0.13, hub)
		if on:
			draw_circle(center, cell * 0.18, Color(glow.r, glow.g, glow.b, 0.3))
		draw_circle(center, cell * 0.06, Palette.BG_TILE if not on else Palette.NODE)

	# lamp: a bulb ring that fills when power reaches it
	if board.lamp[i] == 1:
		var warm := Palette.ACCENT_WARM
		if on:
			draw_circle(center, cell * 0.3, Color(warm.r, warm.g, warm.b, 0.25))
			draw_circle(center, cell * 0.17, warm)
		else:
			draw_arc(center, cell * 0.2, 0.0, TAU, 32, warm, cell * 0.05, true)

	# lock indicator (a small padlock) for fixed tiles
	if is_locked:
		_draw_lock(center, rejecting)

	# hint: a clear pulsing ring + a clockwise-rotate arrow on the target tile
	if _hint_cell == i and _hint_timer > 0.0:
		var pr: float = 0.5 + 0.5 * sin(_hint_timer * 8.0)
		var ring_r: float = cell * 0.44
		var ring_col := Color(Palette.ACCENT_WARM.r, Palette.ACCENT_WARM.g, Palette.ACCENT_WARM.b, 0.5 + 0.5 * pr)
		draw_arc(center, ring_r, 0.0, TAU, 40, ring_col, cell * 0.05 + cell * 0.03 * pr, true)
		# small CW arrow cue
		var ar: float = cell * 0.3
		draw_arc(center, ar, -PI * 0.5, PI * 0.9, 20, Palette.ACCENT_WARM, cell * 0.04, true)
		var tip := center + Vector2(cos(PI * 0.9), sin(PI * 0.9)) * ar
		draw_circle(tip, cell * 0.05, Palette.ACCENT_WARM)

	if _solved:
		var pulse: float = 0.5 + 0.5 * sin(_win_pulse * 6.0 - (row + col) * 0.5)
		draw_circle(center, cell * 0.1 * pulse, Color(Palette.WIRE_GLOW.r, Palette.WIRE_GLOW.g, Palette.WIRE_GLOW.b, 0.25 * pulse))

func _draw_lock(center: Vector2, rejecting: bool = false) -> void:
	# a central padlock so the "fixed" state reads clearly; it punches when tapped
	var c := Palette.DANGER if rejecting else Palette.TEXT_DIM
	var scale := 1.0
	if rejecting:
		scale = 1.0 + 0.4 * (_reject_t / 0.4)
	var r := cell * 0.13 * scale
	var pos := center + Vector2(cell * 0.29, -cell * 0.29)  # top-right badge
	# shackle (upper arc)
	draw_arc(pos + Vector2(0, -r * 0.35), r * 0.5, PI, TAU, 12, c, cell * 0.05 * scale, true)
	# body
	var body := Rect2(pos - Vector2(r * 0.55, r * 0.05), Vector2(r * 1.1, r * 0.85))
	draw_rect(body, c, true)
	# keyhole
	draw_circle(pos + Vector2(0, r * 0.3), r * 0.13, Palette.BG_TILE)

func _dir_vector(dir: int) -> Vector2:
	match dir:
		Puzzle.N: return Vector2(0, -1)
		Puzzle.E: return Vector2(1, 0)
		Puzzle.S: return Vector2(0, 1)
		Puzzle.W: return Vector2(-1, 0)
	return Vector2.ZERO

func _draw_rect_outline(r: Rect2, c: Color, w: float) -> void:
	draw_rect(r, c, false, w)
