extends Control

# Prototype lab: alternative core loops side by side, every level open, so they
# can be played and compared quickly. Not part of the main progression.

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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	col.add_child(header)
	var back := UI.icon_button("<")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	header.add_child(back)
	var title := UI.label("PROTOTYPES", Palette.FONT_H1, Palette.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 22)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for mode in Levels.MODES:
		var name_lbl := UI.label(Levels.mode_title(mode), Palette.FONT_BODY, Palette.TEXT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(name_lbl)
		var rule_lbl := UI.label(Levels.mode_rule(mode), Palette.FONT_SMALL, Palette.TEXT_DIM)
		rule_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(rule_lbl)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 18)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(grid)
		for lvl in range(Levels.proto_count(mode)):
			grid.add_child(_make_chip(mode, lvl))

func _make_chip(mode: String, level: int) -> Control:
	var done := Save.proto_completed(mode, level)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	sb.bg_color = Palette.BG_PANEL
	sb.set_border_width_all(3)
	sb.border_color = Palette.WIRE_ON if done else Palette.GRID_LINE
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, sb)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(UI.label(str(level + 1), Palette.FONT_BODY, Palette.TEXT))
	v.add_child(UI.label("●" if done else "○", Palette.FONT_SMALL, Palette.WIRE_ON if done else Palette.TEXT_DIM))

	b.pressed.connect(func():
		Audio.play("tap")
		Levels.current_mode = mode
		Levels.current_level = level
		get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	return b
