extends Node

# Procedural audio: all SFX are synthesized at runtime into AudioStreamWAV,
# so the game ships with no external audio assets and no licensing concerns.

const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}

func _ready() -> void:
	for _i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_cache["rotate"] = _sweep(240.0, 360.0, 0.07, 0.25)
	_cache["tap"] = _tone(430.0, 0.05, 0.3, "square")
	_cache["connect"] = _tone(680.0, 0.11, 0.3, "sine", 0.015)
	_cache["hint"] = _tone(900.0, 0.18, 0.22, "sine", 0.02)
	_cache["error"] = _tone(150.0, 0.14, 0.3, "square")
	_cache["win"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.11, 0.28)

func play(key: String) -> void:
	if not Save.get_setting("sfx"):
		return
	if not _cache.has(key):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[key]
	p.play()

# --- synthesis helpers -----------------------------------------------------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: float = clampf(samples[i], -1.0, 1.0)
		var s := int(v * 32767.0)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _osc(phase: float, type: String) -> float:
	match type:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle":
			return asin(sin(phase)) * (2.0 / PI)
		_:
			return sin(phase)

# Short envelope-shaped tone. `attack` seconds of fade-in; exponential decay.
func _tone(freq: float, dur: float, vol: float, type: String = "sine", attack: float = 0.005) -> AudioStreamWAV:
	var count := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	var phase := 0.0
	var inc := TAU * freq / RATE
	for i in range(count):
		var t := float(i) / RATE
		var env := 1.0
		if t < attack:
			env = t / attack
		else:
			env = exp(-3.0 * (t - attack) / dur)
		s[i] = _osc(phase, type) * env * vol
		phase += inc
	return _wav(s)

func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var count := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / RATE
		var frac := t / dur
		var freq: float = lerp(f0, f1, frac)
		var env: float = exp(-3.5 * frac)
		s[i] = sin(phase) * env * vol
		phase += TAU * freq / RATE
	return _wav(s)

func _arpeggio(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var total := int(note_dur * freqs.size() * RATE)
	var s := PackedFloat32Array()
	s.resize(total)
	for n in range(freqs.size()):
		var freq: float = freqs[n]
		var start := int(n * note_dur * RATE)
		var phase := 0.0
		var inc := TAU * freq / RATE
		var ncount := int(note_dur * RATE * 1.8)  # let notes ring/overlap
		for i in range(ncount):
			var gi := start + i
			if gi >= total:
				break
			var t := float(i) / RATE
			var env: float = exp(-4.0 * t / note_dur)
			s[gi] += sin(phase) * env * vol
			phase += inc
	return _wav(s)
