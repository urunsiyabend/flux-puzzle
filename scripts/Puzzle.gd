class_name Puzzle
extends RefCounted

# FLUX core puzzle logic: deterministic grid of rotatable connectors.
#
# Direction bitmask: N=1 (up), E=2 (right), S=4 (down), W=8 (left).
# A cell's "mask" is the OR of the directions in which it has a connector.
# Rotating a cell 90 deg clockwise rotates its mask bits.
#
# Win condition: for every connector a cell exposes toward a direction, the
# neighbour in that direction must exist and expose the opposite connector.
# (Mutually matched, with no connector pointing off the board.)

const N := 1
const E := 2
const S := 4
const W := 8
const ALL := 15

# dir -> (drow, dcol)
const DELTA := {
	1: Vector2i(0, -1),  # N: row-1
	2: Vector2i(1, 0),   # E: col+1
	4: Vector2i(0, 1),   # S: row+1
	8: Vector2i(-1, 0),  # W: col-1
}

const DIRS := [1, 2, 4, 8]

static func opposite(d: int) -> int:
	match d:
		1: return 4
		4: return 1
		2: return 8
		8: return 2
	return 0

# Rotate a 4-bit mask one step clockwise (N->E->S->W->N).
static func rotate_cw(mask: int) -> int:
	return ((mask << 1) | (mask >> 3)) & ALL

# Rotate a mask by `steps` clockwise quarter turns.
static func rotate(mask: int, steps: int) -> int:
	var m := mask
	for _i in range(((steps % 4) + 4) % 4):
		m = rotate_cw(m)
	return m

# Count bits set (number of connectors on a tile).
static func popcount(mask: int) -> int:
	var c := 0
	for d in DIRS:
		if mask & d:
			c += 1
	return c
