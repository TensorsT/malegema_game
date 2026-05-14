extends RefCounted
class_name SaveManager

const SAVE_PATH := "user://savegame.json"

static var pending_restore: bool = false

static func request_restore() -> void:
	pending_restore = true

static func consume_restore() -> bool:
	var result := pending_restore
	pending_restore = false
	return result

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_game(board_tile_db: Dictionary, board_game_state: Dictionary) -> void:
	var save_data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"run": RunManager.run,
		"deck": RunManager.deck,
		"levels": RunManager.levels,
		"last_round_result": RunManager.last_round_result,
		"tile_db": board_tile_db,
		"game_state": {
			"points": int(board_game_state.get("points", 0)),
			"coins": int(board_game_state.get("coins", 0)),
			"time": float(board_game_state.get("time", 0.0)),
			"end_condition": String(board_game_state.get("end_condition", "")),
			"dragon_run": board_game_state.get("dragon_run", {}),
			"phoenix_run": board_game_state.get("phoenix_run", {}),
			"temporary_material": String(board_game_state.get("temporary_material", "")),
			"enabled_modules": board_game_state.get("enabled_modules", GameLoop.MODULE_ORDER.duplicate()),
		},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


static func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func restore_run_manager(data: Dictionary) -> void:
	RunManager.run = _ensure_dict(data.get("run", {}))
	RunManager.deck = _ensure_array_of_dicts(data.get("deck", []))
	RunManager.levels = data.get("levels", [])
	RunManager.last_round_result = _ensure_dict(data.get("last_round_result", {}))
	RunManager.ensure_deck_initialized()


static func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


static func _ensure_dict(value) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _ensure_array_of_dicts(value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result
