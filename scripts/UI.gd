class_name UI
extends RefCounted

# Shared UI factory: consistent neon styling without external theme resources.

static func _sb(bg: Color, radius: int = 22, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	return s

static func primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", Palette.FONT_H1)
	b.add_theme_color_override("font_color", Palette.BG)
	b.add_theme_color_override("font_hover_color", Palette.BG)
	b.add_theme_color_override("font_pressed_color", Palette.BG)
	b.add_theme_stylebox_override("normal", _sb(Palette.ACCENT))
	b.add_theme_stylebox_override("hover", _sb(Palette.WIRE_GLOW))
	b.add_theme_stylebox_override("pressed", _sb(Palette.WIRE_ON.darkened(0.15)))
	b.add_theme_stylebox_override("focus", _sb(Palette.ACCENT))
	_wire_sfx(b)
	return b

static func ghost_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", Palette.FONT_BODY)
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_hover_color", Palette.ACCENT)
	b.add_theme_color_override("font_pressed_color", Palette.ACCENT)
	b.add_theme_stylebox_override("normal", _sb(Palette.BG_PANEL, 18, Palette.GRID_LINE, 2))
	b.add_theme_stylebox_override("hover", _sb(Palette.BG_TILE, 18, Palette.ACCENT, 2))
	b.add_theme_stylebox_override("pressed", _sb(Palette.BG_PANEL, 18, Palette.ACCENT, 2))
	b.add_theme_stylebox_override("focus", _sb(Palette.BG_PANEL, 18, Palette.GRID_LINE, 2))
	_wire_sfx(b)
	return b

static func icon_button(glyph: String) -> Button:
	var b := ghost_button(glyph)
	b.add_theme_font_size_override("font_size", Palette.FONT_H1)
	b.custom_minimum_size = Vector2(110, 110)
	return b

static func label(text: String, size: int, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func _wire_sfx(b: Button) -> void:
	b.pressed.connect(func(): Audio.play("tap"))
