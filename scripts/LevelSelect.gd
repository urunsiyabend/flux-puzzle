extends Control

# Level select, grouped into worlds. Progression is linear: solve to unlock the next.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 48)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	# header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	col.add_child(header)
	var back := UI.icon_button("<")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	header.add_child(back)
	var title := UI.label("LEVELS", Palette.FONT_H1, Palette.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	header.add_child(UI.label("%d / %d" % [Save.data["completed"].size(), Levels.count()], Palette.FONT_BODY, Palette.TEXT_DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 22)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var worlds := int(ceil(float(Levels.count()) / Levels.PER_WORLD))
	for w in range(worlds):
		list.add_child(_world_header(w))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 22)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(grid)
		for s in range(Levels.PER_WORLD):
			var lvl := w * Levels.PER_WORLD + s
			if lvl >= Levels.count():
				break
			grid.add_child(_make_chip(lvl))

func _world_header(w: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var wname: String = Levels.WORLD_NAMES[clampi(w, 0, Levels.WORLD_NAMES.size() - 1)]
	var unlocked := Save.is_unlocked(w * Levels.PER_WORLD)
	var c := Palette.TEXT if unlocked else Palette.TEXT_DIM
	row.add_child(UI.label("WORLD %d · %s" % [w + 1, wname], Palette.FONT_BODY, c))
	return row

func _make_chip(level: int) -> Control:
	var unlocked := Save.is_unlocked(level)
	var done := Save.is_completed(level)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not unlocked

	var tier_col := Palette.tier_color(Levels.tier(level))
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(20)
	normal.bg_color = Palette.BG_PANEL if unlocked else Palette.BG_TILE.darkened(0.3)
	normal.set_border_width_all(3)
	normal.border_color = tier_col if unlocked else Palette.GRID_LINE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("disabled", normal)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	if unlocked:
		v.add_child(UI.label(str(level + 1), Palette.FONT_H1, Palette.TEXT))
		# solved levels glow like a lit circuit node; unsolved ones stay dim
		v.add_child(UI.label("●" if done else "○", Palette.FONT_SMALL, Palette.WIRE_ON if done else Palette.TEXT_DIM))
		b.pressed.connect(func():
			Audio.play("tap")
			Levels.current_level = level
			Levels.current_mode = ""
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	else:
		v.add_child(UI.label("🔒", Palette.FONT_H1, Palette.TEXT_DIM))
	return b
