extends Node

# Central colour + typography system so the whole game reads as one product.
# Also the first autoload loaded, so it locks the device to portrait at runtime
# (the prebuilt Android template manifest ships screenOrientation=unspecified).

func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)

const BG := Color(0.055, 0.067, 0.11)          # deep navy
const BG_PANEL := Color(0.09, 0.105, 0.16)
const BG_TILE := Color(0.12, 0.14, 0.2)
const GRID_LINE := Color(0.18, 0.21, 0.29)

const WIRE_OFF := Color(0.32, 0.38, 0.5)        # unmatched / inert
const WIRE_ON := Color(0.18, 0.9, 0.78)         # energised cyan
const WIRE_GLOW := Color(0.6, 1.0, 0.92)
const NODE := Color(0.95, 0.98, 1.0)

const ACCENT := Color(0.18, 0.9, 0.78)
const ACCENT_WARM := Color(1.0, 0.72, 0.36)     # hints / stars
const DANGER := Color(0.95, 0.42, 0.42)

const TEXT := Color(0.92, 0.95, 1.0)
const TEXT_DIM := Color(0.58, 0.64, 0.76)

const FONT_TITLE := 110
const FONT_H1 := 64
const FONT_BODY := 42
const FONT_SMALL := 34

# Difficulty tiers mapped to colours (for level-select chips).
static func tier_color(stars_needed: int) -> Color:
	match stars_needed:
		0, 1: return Color(0.4, 0.85, 0.6)
		2: return Color(0.4, 0.75, 0.95)
		_: return Color(0.78, 0.55, 0.95)
