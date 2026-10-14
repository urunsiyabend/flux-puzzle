extends Control

# Main menu.

var _backdrop: Backdrop

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_backdrop.set_size(get_viewport_rect().size)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	# logo mark
	var mark := _make_logo()
	root.add_child(mark)

	var title := UI.label("FLUX", Palette.FONT_TITLE, Palette.TEXT)
	root.add_child(title)
	var sub := UI.label("connect the circuit", Palette.FONT_BODY, Palette.TEXT_DIM)
	root.add_child(sub)

	root.add_child(_spacer(40))

	var play := UI.primary_button("PLAY")
	play.custom_minimum_size = Vector2(440, 0)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play)
	root.add_child(play)

	var levels := UI.ghost_button("LEVELS")
	levels.custom_minimum_size = Vector2(440, 0)
	levels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	levels.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	root.add_child(levels)

	# settings row
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	var sfx := UI.ghost_button(_sfx_label())
	sfx.pressed.connect(func():
		Save.set_setting("sfx", not Save.get_setting("sfx"))
		sfx.text = _sfx_label())
	row.add_child(sfx)

	root.add_child(_spacer(20))
	root.add_child(UI.label("%d / %d solved" % [Save.data["completed"].size(), Levels.count()], Palette.FONT_SMALL, Palette.TEXT_DIM))

func _on_play() -> void:
	# resume at the furthest level that is actually unlocked (linear progression)
	var lvl := 0
	for i in range(Levels.count()):
		if Save.is_unlocked(i):
			lvl = i
	Levels.current_level = lvl
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _sfx_label() -> String:
	return "SOUND: ON" if Save.get_setting("sfx") else "SOUND: OFF"

func _make_logo() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(220, 220)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var d := LogoDraw.new()
	d.position = Vector2(110, 110)
	c.add_child(d)
	return c

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


# Small animated logo glyph.
class LogoDraw extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var r := 78.0
		var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(-0.7, 0.7)]
		for v in dirs:
			draw_line(Vector2.ZERO, v * r, Palette.WIRE_ON, 11.0, true)
			draw_circle(v * r, 12.0, Palette.WIRE_GLOW)
		var pulse := 1.0 + 0.08 * sin(t * 3.0)
		draw_circle(Vector2.ZERO, 26.0 * pulse, Palette.BG)
		draw_arc(Vector2.ZERO, 26.0 * pulse, 0, TAU, 32, Palette.WIRE_ON, 9.0, true)
		draw_circle(Vector2.ZERO, 9.0, Palette.ACCENT_WARM)
