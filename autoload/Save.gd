extends Node

# Persistent save data: progression, best scores, settings.

const PATH := "user://flux_save.json"

var autosave := true   # tests disable this to avoid touching the real file

var data := {
	"version": 1,
	"completed": {},      # level_index (as string) -> best move count
	"max_unlocked": 0,    # highest level index unlocked (0-based)
	"proto": {},          # mode -> {level_index: best move count} (prototype lab)
	"settings": {
		"sfx": true,
		"music": true,
	},
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		# merge defensively so missing keys keep defaults
		for k in parsed.keys():
			data[k] = parsed[k]
		if not data.has("settings"):
			data["settings"] = {"sfx": true, "music": true}

func save_data() -> void:
	if not autosave:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Flux: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data))
	f.close()

func is_completed(level: int) -> bool:
	return data["completed"].has(str(level))

func best_moves(level: int) -> int:
	if is_completed(level):
		return int(data["completed"][str(level)])
	return -1

func is_unlocked(level: int) -> bool:
	return level <= int(data["max_unlocked"])

func complete_level(level: int, moves: int) -> void:
	var key := str(level)
	if not data["completed"].has(key) or moves < int(data["completed"][key]):
		data["completed"][key] = moves
	if level + 1 > int(data["max_unlocked"]):
		data["max_unlocked"] = level + 1
	save_data()

func proto_completed(mode: String, level: int) -> bool:
	return data.get("proto", {}).get(mode, {}).has(str(level))

func complete_proto(mode: String, level: int, moves: int) -> void:
	if not data.has("proto"):
		data["proto"] = {}
	if not data["proto"].has(mode):
		data["proto"][mode] = {}
	var key := str(level)
	var rec: Dictionary = data["proto"][mode]
	if not rec.has(key) or moves < int(rec[key]):
		rec[key] = moves
	save_data()

func get_setting(key: String) -> bool:
	return bool(data["settings"].get(key, true))

func set_setting(key: String, value: bool) -> void:
	data["settings"][key] = value
	save_data()

func reset_progress() -> void:
	data["completed"] = {}
	data["max_unlocked"] = 0
	save_data()
