extends Control

const BASE_CARDS := [
	"bam1", "bam2", "bam3",
	"crack1", "crack2",
	"dot1",
]
const SPECIAL_CARDS := [
	"dragonr", "phoenix", "gemr", "mutation1", "windn", "joker",
]
const MAX_TILES := 12
const TILE_SCENE := preload("res://scene/Tile.tscn")
const CLICK_STREAM := preload("res://sounds/click.mp3")
const MATCH_STREAM := preload("res://sounds/gemstone.mp3")

const STEP_X := 40
const STEP_Y := 54
const Z_OFFSET_X := 6
const Z_OFFSET_Y := 12
const TILE_DRAW_SIZE := Vector2(82, 120)
const BOARD_PADDING := Vector2(54, 34)

@onready var board_container: Control = $GamePanel/VBoxContainer/BoardContainer
@onready var tile_layer: Control = $GamePanel/VBoxContainer/BoardContainer/TileLayer
@onready var status_label: Label = $GamePanel/VBoxContainer/StatusLabel

var tile_db: Dictionary = {}
var tile_nodes: Dictionary = {}
var icon_cache: Dictionary = {}

var click_player: AudioStreamPlayer
var match_player: AudioStreamPlayer
var board_tween: Tween

var game_state := {
	"points": 0,
	"end_condition": "",
	"dragon_run": {},
	"phoenix_run": {},
	"temporary_material": "",
	"enabled_modules": GameLoop.MODULE_ORDER.duplicate(),
}


func _ready() -> void:
	_setup_audio()
	board_container.resized.connect(_on_board_container_resized)
	_on_board_container_resized()
	_setup_new_round()


func _setup_new_round() -> void:
	tile_db.clear()
	tile_nodes.clear()
	game_state = {
		"points": 0,
		"end_condition": "",
		"dragon_run": {},
		"phoenix_run": {},
		"temporary_material": "",
		"enabled_modules": GameLoop.MODULE_ORDER.duplicate(),
	}

	for child in tile_layer.get_children():
		child.queue_free()

	board_container.scale = Vector2.ONE
	board_container.rotation_degrees = 0.0

	var deck := _build_deck(int(MAX_TILES / 2.0))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	game_state["rng"] = rng
	tile_db = SetupTiles.setup_tiles(rng, deck)

	for tile in _sorted_tiles(tile_db):
		var tile_id := String(tile["id"])
		var card_id := String(tile["card_id"])
		var material_name := String(tile.get("material", "bone"))

		var tile_node := TILE_SCENE.instantiate() as Tile
		tile_layer.add_child(tile_node)
		tile_node.setup(tile_id, card_id, _get_icon(card_id), material_name)
		tile_node.position = _to_screen_position(tile)
		tile_node.z_index = int(tile["z"]) * 100 + int(tile["x"]) + int(tile["y"]) * 2
		tile_node.tile_clicked.connect(_on_tile_pressed)
		tile_node.tree_exited.connect(_on_tile_node_tree_exited.bind(tile_id, tile_node))

		tile_nodes[tile_id] = tile_node

	_refresh_tiles_state()
	status_label.text = "找到可解牌局，当前分数：0"


func _on_tile_pressed(tile_id: String) -> void:
	if not tile_db.has(tile_id):
		return

	var tile: Dictionary = tile_db[tile_id]
	if bool(tile["deleted"]):
		return
	if String(game_state.get("end_condition", "")) != "":
		return

	if not TileRules.is_free(tile_db, tile):
		_play_click_sound(0.84, -12.0)
		status_label.text = "这张牌当前不可点击：上方有压牌，或左右都被堵住。"
		var blocked_tile_node := _get_live_tile_node(tile_id)
		if blocked_tile_node != null:
			blocked_tile_node.play_invalid_feedback()
		_play_board_bump(false)
		return

	_play_click_sound(1.02, -8.0)
	var result := GameLoop.select_tile(tile_db, game_state, tile_id)
	_refresh_tiles_state()
	_play_result_feedback(result)
	_status_from_result(result)


func _status_from_result(result: Dictionary) -> void:
	var kind := String(result.get("kind", ""))
	var end_condition := String(game_state.get("end_condition", ""))
	if end_condition == "empty-board":
		status_label.text = "全部清空，过关。总分：%d" % int(game_state["points"])
		return
	if end_condition == "no-pairs":
		status_label.text = "没有可消对，游戏结束。总分：%d" % int(game_state["points"])
		return

	match kind:
		"selected-first":
			status_label.text = "已选择第一张牌"
		"unselected":
			status_label.text = "已取消选择，当前分数：%d" % int(game_state["points"])
		"matched":
			status_label.text = "配对成功 +%d，当前分数：%d" % [
				int(result.get("points", 0)),
				int(game_state["points"]),
			]
		"mismatch":
			status_label.text = "这两张不能消除，当前分数：%d" % int(game_state["points"])
		_:
			status_label.text = "当前分数：%d" % int(game_state["points"])


func _apply_tile_visual(tile_id: String) -> void:
	if not tile_nodes.has(tile_id) or not tile_db.has(tile_id):
		return

	var tile_node := _get_live_tile_node(tile_id)
	if tile_node == null:
		return

	var tile: Dictionary = tile_db[tile_id]
	if bool(tile["deleted"]):
		if tile_node.visible:
			tile_node.play_remove()
		return

	var card_id := String(tile["card_id"])
	var material_name := String(tile.get("material", "bone"))
	tile_node.visible = true
	tile_node.setup(tile_id, card_id, _get_icon(card_id), material_name)

	var free := TileRules.is_free(tile_db, tile)
	tile_node.set_clickable(free)
	tile_node.set_selected(bool(tile["selected"]))
	tile_node.position = _to_screen_position(tile)
	tile_node.z_index = int(tile["z"]) * 100 + int(tile["x"]) + int(tile["y"]) * 2


func _refresh_tiles_state() -> void:
	for tile_id in tile_nodes.keys():
		_apply_tile_visual(String(tile_id))


func _get_live_tile_node(tile_id: String) -> Tile:
	var node_ref = tile_nodes.get(tile_id, null)
	if node_ref == null or not is_instance_valid(node_ref):
		tile_nodes.erase(tile_id)
		return null
	return node_ref as Tile


func _on_tile_node_tree_exited(tile_id: String, exited_node: Tile) -> void:
	var current_node = tile_nodes.get(tile_id, null)
	if current_node == exited_node:
		tile_nodes.erase(tile_id)


func _to_screen_position(tile: Dictionary) -> Vector2:
	var origin := _get_layout_origin()
	var raw_position := _to_layout_space(tile)
	return raw_position + origin


func _to_layout_space(tile: Dictionary) -> Vector2:
	var x := int(tile["x"])
	var y := int(tile["y"])
	var z := int(tile["z"])
	return Vector2(
		float(x * STEP_X) - float(z * Z_OFFSET_X),
		float(y * STEP_Y) - float(z * Z_OFFSET_Y)
	)


func _get_layout_origin() -> Vector2:
	var bounds := _get_layout_bounds()
	var available_size := board_container.size - BOARD_PADDING * 2.0
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return -bounds.position

	return BOARD_PADDING + (available_size - bounds.size) * 0.5 - bounds.position


func _get_layout_bounds() -> Rect2:
	var has_tile := false
	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO

	for tile_value in tile_db.values():
		var tile: Dictionary = tile_value
		var tile_pos := _to_layout_space(tile)
		var tile_rect := Rect2(tile_pos, TILE_DRAW_SIZE)

		if not has_tile:
			min_pos = tile_rect.position
			max_pos = tile_rect.end
			has_tile = true
			continue

		min_pos.x = minf(min_pos.x, tile_rect.position.x)
		min_pos.y = minf(min_pos.y, tile_rect.position.y)
		max_pos.x = maxf(max_pos.x, tile_rect.end.x)
		max_pos.y = maxf(max_pos.y, tile_rect.end.y)

	if not has_tile:
		return Rect2(Vector2.ZERO, TILE_DRAW_SIZE)

	return Rect2(min_pos, max_pos - min_pos)


func _build_deck(pair_count: int) -> Array[Dictionary]:
	var card_ids: Array[String] = []
	if pair_count <= 0:
		return []

	var base_quota := maxi(1, int(floor(pair_count / 2.0)))
	var special_quota := pair_count - base_quota
	if special_quota <= 0:
		special_quota = 1
		base_quota = pair_count - 1

	card_ids.append_array(_fill_quota(BASE_CARDS, base_quota))
	card_ids.append_array(_fill_quota(SPECIAL_CARDS, special_quota))
	card_ids.shuffle()

	var deck: Array[Dictionary] = []
	for i in range(card_ids.size()):
		deck.append({
			"id": str(i),
			"cardId": card_ids[i],
			"material": "bone",
		})
	return deck


func _fill_quota(pool: Array, quota: int) -> Array[String]:
	var result: Array[String] = []
	if quota <= 0 or pool.is_empty():
		return result

	var source: Array = pool.duplicate()
	source.shuffle()
	var index := 0
	while result.size() < quota:
		result.append(String(source[index]))
		index += 1
		if index >= source.size():
			source.shuffle()
			index = 0

	return result


func _sorted_tiles(db: Dictionary) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for value in db.values():
		tiles.append(value as Dictionary)

	tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["z"]) != int(b["z"]):
			return int(a["z"]) < int(b["z"])
		if int(a["y"]) != int(b["y"]):
			return int(a["y"]) < int(b["y"])
		return int(a["x"]) < int(b["x"])
	)
	return tiles


func _on_restart_button_pressed() -> void:
	_setup_new_round()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")


func _get_icon(card_id: String) -> Texture2D:
	if icon_cache.has(card_id):
		return icon_cache[card_id]

	var path := "res://tiles/%s.webp" % card_id
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		icon_cache[card_id] = texture
		return texture

	return null


func _setup_audio() -> void:
	click_player = AudioStreamPlayer.new()
	click_player.stream = CLICK_STREAM
	click_player.volume_db = -8.0
	add_child(click_player)

	match_player = AudioStreamPlayer.new()
	match_player.stream = MATCH_STREAM
	match_player.volume_db = -4.0
	add_child(match_player)


func _play_click_sound(pitch: float, volume_db: float) -> void:
	if click_player == null:
		return
	click_player.pitch_scale = pitch
	click_player.volume_db = volume_db
	click_player.play()


func _play_match_sound() -> void:
	if match_player == null:
		return
	match_player.pitch_scale = randf_range(0.94, 1.06)
	match_player.play()


func _play_result_feedback(result: Dictionary) -> void:
	match String(result.get("kind", "")):
		"matched":
			_play_match_sound()
			_play_board_bump(true)
		"mismatch":
			_play_board_bump(false)
		"selected-first":
			_play_board_focus()
		_:
			pass


func _play_board_focus() -> void:
	_update_board_pivot()
	if board_tween != null and board_tween.is_valid():
		board_tween.kill()

	board_tween = create_tween()
	board_tween.set_parallel(true)
	board_tween.tween_property(board_container, "scale", Vector2(1.01, 1.01), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board_container, "rotation_degrees", -0.18, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.chain().set_parallel(true)
	board_tween.tween_property(board_container, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board_container, "rotation_degrees", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_board_bump(strong: bool) -> void:
	_update_board_pivot()
	if board_tween != null and board_tween.is_valid():
		board_tween.kill()

	var target_scale := Vector2(0.996, 1.008)
	var target_rotation := 0.35
	var attack := 0.05
	var release := 0.13
	if strong:
		target_scale = Vector2(0.986, 1.018)
		target_rotation = -0.7
		attack = 0.08
		release = 0.20

	board_tween = create_tween()
	board_tween.set_parallel(true)
	board_tween.tween_property(board_container, "scale", target_scale, attack).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board_container, "rotation_degrees", target_rotation, attack).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.chain().set_parallel(true)
	board_tween.tween_property(board_container, "scale", Vector2.ONE, release).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board_container, "rotation_degrees", 0.0, release).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_board_pivot() -> void:
	board_container.pivot_offset = board_container.size * 0.5


func _on_board_container_resized() -> void:
	_update_board_pivot()
	if not tile_db.is_empty():
		_refresh_tiles_state()
