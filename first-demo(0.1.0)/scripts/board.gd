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
const BOARD_PADDING := Vector2(54, 42)
const MAX_LAYOUT_SCALE := 1.45

@onready var board_container: Control = $GamePanel/VBoxContainer/BoardContainer
@onready var tile_layer: Control = $GamePanel/VBoxContainer/BoardContainer/TileLayer
@onready var game_panel: Panel = $GamePanel
@onready var title_label: Label = $GamePanel/VBoxContainer/TitleLabel
@onready var status_label: Label = $GamePanel/VBoxContainer/StatusLabel
@onready var board_shadow: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardShadow
@onready var board_surface: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardSurface
@onready var board_inset: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardInset
@onready var board_glow: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardGlow
@onready var restart_button: Button = $GamePanel/VBoxContainer/ActionRow/RestartButton
@onready var back_button: Button = $GamePanel/VBoxContainer/ActionRow/BackButton

var tile_db: Dictionary = {}
var tile_nodes: Dictionary = {}
var icon_cache: Dictionary = {}

var click_player: AudioStreamPlayer
var match_player: AudioStreamPlayer
var board_tween: Tween
var _layout_scale: float = 1.0

var game_state := {
	"points": 0,
	"coins": 0,
	"time": 0.0,
	"end_condition": "",
	"dragon_run": {},
	"phoenix_run": {},
	"temporary_material": "",
	"enabled_modules": GameLoop.MODULE_ORDER.duplicate(),
}


func _ready() -> void:
	_apply_whatajong_ui()
	_setup_audio()
	board_container.resized.connect(_on_board_container_resized)
	_on_board_container_resized()
	_setup_new_round()
	set_process(true)


func _process(delta: float) -> void:
	if String(game_state.get("end_condition", "")) != "":
		return
	game_state["time"] = float(game_state.get("time", 0.0)) + delta


func _setup_new_round() -> void:
	tile_db.clear()
	tile_nodes.clear()
	game_state = {
		"points": 0,
		"coins": 0,
		"time": 0.0,
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
	restart_button.text = "重新开局"

	var deck: Array[Dictionary] = []
	var rng: RandomNumberGenerator
	if RunManager.has_active_run():
		deck = RunManager.deck
		rng = RunManager.get_round_rng()
		_apply_round_header()
	else:
		deck = _build_deck(int(MAX_TILES / 2.0))
		rng = RandomNumberGenerator.new()
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
	if RunManager.has_active_run():
		var round := RunManager.get_round()
		status_label.text = "目标分数：%d，当前分数：0" % int(round.get("pointObjective", 0))
	else:
		status_label.text = "找到可解牌局，当前分数：0"


func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(game_panel, WhatajongUI.COLOR_DOT, Color(0.97, 0.94, 0.86, 0.86), 30, 22)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(restart_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(back_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_button(restart_button, WhatajongUI.COLOR_CRACK, 0.90)
	WhatajongUI.apply_button(back_button, WhatajongUI.COLOR_DOT, 0.90)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_DOT.darkened(0.38))
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)

	board_shadow.color = Color(0.03, 0.04, 0.05, 0.24)
	board_surface.color = Color(0.20, 0.40, 0.34, 0.94)
	board_inset.color = Color(0.28, 0.50, 0.42, 0.50)
	board_glow.color = Color(0.84, 0.96, 0.86, 0.14)


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
		return

	_play_click_sound(1.02, -8.0)
	var result := GameLoop.select_tile(tile_db, game_state, tile_id)
	_refresh_tiles_state()
	_play_result_feedback(result)
	_status_from_result(result)
	if String(game_state.get("end_condition", "")) != "":
		_handle_round_end()


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
	var scale := _get_layout_scale()
	tile_node.visible = true
	tile_node.setup(tile_id, card_id, _get_icon(card_id), material_name)
	tile_node.scale = Vector2(scale, scale)

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
	var scale := _get_layout_scale()
	return raw_position * scale + origin


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
		return -bounds.position * _get_layout_scale()

	var scale := _get_layout_scale()
	return BOARD_PADDING + (available_size - bounds.size * scale) * 0.5 - bounds.position * scale


func _get_layout_scale() -> float:
	if tile_db.is_empty():
		return 1.0
	var bounds := _get_layout_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 1.0
	var available_size := board_container.size - BOARD_PADDING * 2.0
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return 1.0
	var scale_x := available_size.x / bounds.size.x
	var scale_y := available_size.y / bounds.size.y
	return min(MAX_LAYOUT_SCALE, min(scale_x, scale_y))


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
	if RunManager.has_active_run() and String(game_state.get("end_condition", "")) != "":
		var result := RunManager.last_round_result
		if result.is_empty():
			result = RunManager.evaluate_round(game_state)
		if bool(result.get("win", false)):
			RunManager.advance_after_win()
			RunManager.enter_stage(String(RunManager.run.get("stage", RunManager.STAGE_SHOP)))
			return
		RunManager.retry_round()
	_setup_new_round()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")


func _handle_round_end() -> void:
	if not RunManager.has_active_run():
		return
	var result := RunManager.evaluate_round(game_state)
	if bool(result.get("win", false)):
		restart_button.text = "继续"
		status_label.text = "通关成功，点击继续前往下一阶段。"
	else:
		restart_button.text = "重试"
		status_label.text = "未达成目标，点击重试当前回合。"


func _apply_round_header() -> void:
	if not RunManager.has_active_run():
		return
	var round := RunManager.get_round()
	var round_id := int(RunManager.run.get("round", 1))
	var objective := int(round.get("pointObjective", 0))
	title_label.text = "第 %d 回合" % round_id
	status_label.text = "目标分数：%d" % objective


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
			_play_board_tap()
		_:
			pass


func _play_board_tap() -> void:
	_update_board_pivot()
	if board_tween != null and board_tween.is_valid():
		board_tween.kill()

	board_tween = create_tween()
	board_tween.set_parallel(true)
	board_tween.tween_property(board_container, "scale", Vector2(1.002, 1.002), 0.045).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board_container, "rotation_degrees", -0.035, 0.045).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.chain().set_parallel(true)
	board_tween.tween_property(board_container, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board_container, "rotation_degrees", 0.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_board_bump(strong: bool) -> void:
	_update_board_pivot()
	if board_tween != null and board_tween.is_valid():
		board_tween.kill()

	var target_scale := Vector2(0.998, 1.003)
	var target_rotation := 0.08
	var attack := 0.04
	var release := 0.09
	if strong:
		target_scale = Vector2(0.976, 1.028)
		target_rotation = -0.85
		attack = 0.085
		release = 0.24

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
