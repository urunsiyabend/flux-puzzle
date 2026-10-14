extends Node

# Dev-only screenshot harness. Inactive during normal play; when the env var
# FLUX_SHOT is set to an output directory, it walks the main screens, saves a
# PNG of each from the engine's own framebuffer, then quits. This lets us verify
# the real rendered presentation on a Wayland session where external window
# capture is unreliable.

func _ready() -> void:
	var dir := OS.get_environment("FLUX_SHOT")
	if dir == "":
		return
	_run(dir)

func _run(dir: String) -> void:
	await _wait(0.9)
	await _grab(dir + "/01_menu.png")

	# World 2 level: locked tiles
	Levels.current_level = 9
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
	await _wait(1.1)
	await _grab(dir + "/02_game_locked.png")
	_tap_test()
	await _wait(0.3)
	# hint ring
	_hint_test()
	await _wait(0.25)
	await _grab(dir + "/07_hint.png")
	# locked-tile reject feedback
	_reject_test()
	await _wait(0.12)
	await _grab(dir + "/08_locked_reject.png")

	# World 3 level: holes (irregular board)
	Levels.current_level = 15
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
	await _wait(1.1)
	await _grab(dir + "/06_game_holes.png")

	# auto-solve; capture lit state, then the win panel
	_autosolve()
	await _wait(0.5)
	await _grab(dir + "/03_solved.png")
	await _wait(1.0)
	await _grab(dir + "/05_win.png")

	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
	await _wait(0.9)
	await _grab(dir + "/04_levels.png")

	get_tree().quit()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT saved: ", path, " (", img.get_width(), "x", img.get_height(), ")")

func _tap_test() -> void:
	var game = get_tree().current_scene
	if game == null:
		print("TAP TEST: no scene"); return
	var bv = game.get("board_view")
	if bv == null:
		print("TAP TEST: no board_view"); return
	# pick a movable (non-empty) tile and tap its centre
	var target: int = bv.source_cell
	for i in range(bv.board.base.size()):
		if bv.board.base[i] != 0:
			target = i
			break
	var col: int = target % bv.board.width
	@warning_ignore("integer_division")
	var row: int = target / bv.board.width
	var center: Vector2 = bv.origin + Vector2(col * bv.cell + bv.cell * 0.5, row * bv.cell + bv.cell * 0.5)
	# push_input expects window-pixel coords; convert from the stretched viewport
	var win: Vector2 = Vector2(get_window().size)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var pos: Vector2 = center * (win / vp)
	var before: int = bv.move_count
	var rot_before: int = bv.board.rot[target]
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.index = 0
	down.position = pos
	get_viewport().push_input(down)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.index = 0
	up.position = pos
	get_viewport().push_input(up)
	print("TAP TEST: moves %d -> %d, rot %d -> %d at cell %d" % [before, bv.move_count, rot_before, bv.board.rot[target], target])

func _hint_test() -> void:
	var game = get_tree().current_scene
	if game == null: return
	var bv = game.get("board_view")
	if bv == null: return
	bv.request_hint()

func _reject_test() -> void:
	var game = get_tree().current_scene
	if game == null: return
	var bv = game.get("board_view")
	if bv == null: return
	for i in range(bv.board.locked.size()):
		if bv.board.locked[i] == 1:
			bv._reject_locked(i)
			return

func _autosolve() -> void:
	var game := get_tree().current_scene
	if game == null or not game.has_method("_ready"):
		return
	var bv = game.get("board_view")
	if bv == null:
		return
	# set every tile back to its home orientation, then refresh energy/visuals
	for i in range(bv.board.rot.size()):
		bv.board.rot[i] = 0
		bv._target_angle[i] = 0.0
		bv._display_angle[i] = 0.0
	if bv.board.is_solved():
		bv._win()
	bv.queue_redraw()
