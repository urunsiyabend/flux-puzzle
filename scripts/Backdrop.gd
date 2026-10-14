class_name Backdrop
extends Node2D

# Subtle animated background: drifting glow nodes + faint connecting lines,
# echoing the puzzle theme without distracting from it.

var _pts: Array = []
var _size := Vector2(1080, 1920)
var _t := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in range(16):
		_pts.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"v": Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012)),
			"r": rng.randf_range(3.0, 7.0),
		})

func set_size(s: Vector2) -> void:
	_size = s
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_size = get_viewport_rect().size   # follow the live (expanded) viewport
	for pt in _pts:
		pt["p"] += pt["v"] * delta
		if pt["p"].x < 0.0 or pt["p"].x > 1.0:
			pt["v"].x *= -1.0
		if pt["p"].y < 0.0 or pt["p"].y > 1.0:
			pt["v"].y *= -1.0
	queue_redraw()

func _draw() -> void:
	# faint connecting lines between nearby points
	for a in range(_pts.size()):
		var pa: Vector2 = _pts[a]["p"] * _size
		for b in range(a + 1, _pts.size()):
			var pb: Vector2 = _pts[b]["p"] * _size
			var d := pa.distance_to(pb)
			if d < _size.x * 0.28:
				var alpha: float = (1.0 - d / (_size.x * 0.28)) * 0.08
				draw_line(pa, pb, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, alpha), 2.0, true)
	for pt in _pts:
		var p: Vector2 = pt["p"] * _size
		var r: float = pt["r"]
		var glow: float = 0.5 + 0.5 * sin(_t * 1.5 + p.x * 0.01)
		draw_circle(p, r * 2.2, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.05 * glow))
		draw_circle(p, r, Color(Palette.WIRE_GLOW.r, Palette.WIRE_GLOW.g, Palette.WIRE_GLOW.b, 0.12))
