extends Control

# Gameplay screen: HUD + board + controls + win overlay.

var board_view: BoardView
var _level := 0
var _title_label: Label
var _world_label: Label
var _overlay: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# let taps over the board area fall through to BoardView._unhandled_input;
	# buttons are their own Controls and still receive their own input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level = Levels.current_level

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.set_size(get_viewport_rect().size)

	board_view = BoardView.new()
	add_child(board_view)
	board_view.solved.connect(_on_solved)

	_build_hud()
	_build_controls()
	_load_level()
	get_viewport().size_changed.connect(_relayout)

func _play_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(50, 230, vp.x - 100, vp.y - 230 - 260)

func _relayout() -> void:
	if board_view and board_view.board:
		board_view.refit(_play_rect())

func _load_level() -> void:
	var board := Levels.get_board(_level)
	board_view.setup(board, _play_rect())
	board_view.set_interactive(true)
	_title_label.text = "LEVEL %d" % (_level + 1)
	_world_label.text = Levels.world_name(_level)
	if _overlay:
		_overlay.queue_free()
		_overlay = null

func _build_hud() -> void:
	var bar := HBoxContainer.new()
	# anchored to the top edge, full width, so it holds on any screen height
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = 50
	bar.offset_right = -50
	bar.offset_top = 70
	bar.offset_bottom = 190
	bar.add_theme_constant_override("separation", 20)
	add_child(bar)

	var back := UI.icon_button("<")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	bar.add_child(back)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(mid)
	_title_label = UI.label("", Palette.FONT_BODY, Palette.TEXT)
	mid.add_child(_title_label)
	_world_label = UI.label("", Palette.FONT_SMALL, Palette.TEXT_DIM)
	mid.add_child(_world_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(110, 0)
	bar.add_child(spacer)

func _build_controls() -> void:
	var bar := HBoxContainer.new()
	# anchored to the bottom edge, full width
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 50
	bar.offset_right = -50
	bar.offset_top = -200
	bar.offset_bottom = -60
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 28)
	add_child(bar)

	var undo := _control_button("↶", "UNDO")
	undo.pressed.connect(func(): board_view.undo())
	bar.add_child(undo)

	var hint := _control_button("?", "HINT")
	hint.pressed.connect(func(): board_view.request_hint())
	bar.add_child(hint)

	var restart := _control_button("⟳", "RESTART")
	restart.pressed.connect(func(): _load_level())
	bar.add_child(restart)

func _control_button(glyph: String, caption: String) -> Button:
	var b := UI.ghost_button(glyph + "  " + caption)
	b.add_theme_font_size_override("font_size", Palette.FONT_SMALL)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 120)
	return b

func _on_solved() -> void:
	board_view.set_interactive(false)
	Save.complete_level(_level, board_view.move_count)
	await get_tree().create_timer(0.7).timeout
	_show_win()

func _show_win() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 28)
	center.add_child(panel)

	panel.add_child(UI.label("SOLVED", Palette.FONT_TITLE, Palette.WIRE_ON))

	var nxt_level := _level + 1
	var has_next := nxt_level < Levels.count()
	if has_next and Levels.is_world_start(nxt_level):
		# entering a new world: name it and its one new idea, nothing else
		var w := Levels.world_of(nxt_level)
		panel.add_child(UI.label("NEXT · %s" % Levels.WORLD_NAMES[w].to_upper(), Palette.FONT_BODY, Palette.ACCENT_WARM))
		panel.add_child(UI.label(Levels.world_intro(w), Palette.FONT_SMALL, Palette.TEXT_DIM))
	elif not has_next:
		panel.add_child(UI.label("All levels complete!", Palette.FONT_BODY, Palette.WIRE_GLOW))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	panel.add_child(spacer)

	if has_next:
		var nxt := UI.primary_button("NEXT")
		nxt.custom_minimum_size = Vector2(420, 0)
		nxt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nxt.pressed.connect(func():
			_level += 1
			Levels.current_level = _level
			_load_level())
		panel.add_child(nxt)

	var replay := UI.ghost_button("REPLAY")
	replay.custom_minimum_size = Vector2(420, 0)
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	replay.pressed.connect(func(): _load_level())
	panel.add_child(replay)

	var menu := UI.ghost_button("LEVELS")
	menu.custom_minimum_size = Vector2(420, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	panel.add_child(menu)

	# pop-in animation (scale from the panel's own centre)
	panel.modulate.a = 0.0
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
