extends Node

const DEFAULT_TRACK := "Speed of Light"
const TRACKS := {
	"Speed of Light": "res://sounds/Speed of Light.mp3",
}
const SETTINGS_PATH := "user://music_settings.json"

var _player: AudioStreamPlayer
var _current_track := DEFAULT_TRACK
var _volume_percent := 70.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Master"
	add_child(_player)
	_load_settings()
	_apply_track(_current_track)
	_apply_volume(_volume_percent)
	if _player.stream != null:
		_player.play()


func get_track_names() -> Array[String]:
	var names: Array[String] = []
	for key in TRACKS.keys():
		names.append(String(key))
	names.sort()
	return names


func get_current_track() -> String:
	return _current_track


func set_track(name: String) -> void:
	if not TRACKS.has(name):
		return
	_current_track = name
	_apply_track(name)
	if _player.stream != null and not _player.playing:
		_player.play()
	_save_settings()


func get_volume_percent() -> float:
	return _volume_percent


func set_volume_percent(value: float) -> void:
	_volume_percent = clampf(value, 0.0, 100.0)
	_apply_volume(_volume_percent)
	_save_settings()


func _apply_track(name: String) -> void:
	if not TRACKS.has(name):
		return
	var path := String(TRACKS[name])
	if ResourceLoader.exists(path):
		_player.stream = load(path)


func _apply_volume(value: float) -> void:
	var linear := value / 100.0
	_player.volume_db = linear_to_db(max(linear, 0.0001))


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var track := String(data.get("track", DEFAULT_TRACK))
	if TRACKS.has(track):
		_current_track = track
	_volume_percent = float(data.get("volume", _volume_percent))


func _save_settings() -> void:
	var payload := {
		"track": _current_track,
		"volume": _volume_percent,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()
