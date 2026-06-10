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
const WIND_GUST_OVERLAY_SCRIPT := preload("res://scripts/wind_gust_overlay.gd")
const CLICK_STREAM := preload("res://sounds/click.mp3")
const MATCH_STREAM := preload("res://sounds/gemstone.mp3")
const MATCH_PARTICLES := preload("res://scene/MatchParticles.tscn")
const SELECT_PARTICLES := preload("res://scene/SelectParticles.tscn")
const AMBIENT_PARTICLES := preload("res://scene/AmbientParticles.tscn")

const STEP_X := 40
const STEP_Y := 54
const Z_OFFSET_X := 6
const Z_OFFSET_Y := 12
const TILE_DRAW_SIZE := Vector2(82, 120)
const BOARD_PADDING := Vector2(54, 42)
const MAX_LAYOUT_SCALE := 1.45
const WIND_PUSH_DURATION := 0.24
const WIND_SETTLE_DURATION := 0.12
const WIND_OVERSHOOT_PX := 18.0

@onready var board_container: Control = $GamePanel/VBoxContainer/BoardContainer
@onready var tile_layer: Control = $GamePanel/VBoxContainer/BoardContainer/TileLayer
@onready var game_panel: Panel = $GamePanel
@onready var title_label: Label = $GamePanel/VBoxContainer/TitleLabel
@onready var score_label: Label = $GamePanel/VBoxContainer/ScoreLabel
@onready var score_bar: ProgressBar = $GamePanel/VBoxContainer/ScoreBarRow/ScoreBar
@onready var score_bar_label: Label = $GamePanel/VBoxContainer/ScoreBarRow/ScoreBarLabel
@onready var combo_label: Label = $GamePanel/VBoxContainer/ComboLabel
@onready var timer_bar: ProgressBar = $GamePanel/VBoxContainer/TimerBarRow/TimerBar
@onready var timer_bar_label: Label = $GamePanel/VBoxContainer/TimerBarRow/TimerBarLabel
@onready var status_label: Label = $GamePanel/VBoxContainer/StatusLabel
@onready var board_shadow: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardShadow
@onready var board_surface: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardSurface
@onready var board_inset: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardInset
@onready var board_glow: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardGlow
@onready var restart_button: Button = $GamePanel/VBoxContainer/ActionRow/RestartButton
@onready var save_exit_button: Button = $GamePanel/VBoxContainer/ActionRow/SaveExitButton
@onready var back_button: Button = $GamePanel/VBoxContainer/ActionRow/BackButton

var tile_db: Dictionary = {}
var tile_nodes: Dictionary = {}
var tile_motion_tweens: Dictionary = {}
var icon_cache: Dictionary = {}

var click_player: AudioStreamPlayer
var match_player: AudioStreamPlayer
var wind_gust_overlay: Control
var board_tween: Tween
var _layout_scale: float = 1.0
var _round_end_pending := false
var _ambient_particles: CPUParticles2D
var _inventory_popup: InventoryPopup
var _active_card_ids: Array[String] = []

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
	# 强制确保背包有初始牌
	if RunManager.deck.is_empty():
		RunManager.deck = DeckState.create_initial_deck()
	_apply_whatajong_ui()
	_setup_audio()
	_setup_wind_gust_overlay()
	_setup_ambient_particles()
	_setup_inventory()
	board_container.resized.connect(_on_board_container_resized)
	_on_board_container_resized()
	if SaveManager.consume_restore():
		_load_saved_board()
	else:
		_setup_new_round()
	set_process(true)


func _process(delta: float) -> void:
	if String(game_state.get("end_condition", "")) != "":
		return
	game_state["time"] = float(game_state.get("time", 0.0)) + delta
	_update_score_label()
	_update_score_bar()
	_update_combo_label()
	_update_timer_bar()


func _setup_new_round() -> void:
	_kill_tile_motion_tweens()
	tile_db.clear()
	tile_nodes.clear()
	_active_card_ids.clear()
	_round_end_pending = false
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

	# 确保背包有初始牌
	if RunManager.deck.is_empty():
		RunManager.deck = DeckState.create_initial_deck()
	RunManager.ensure_deck_initialized()

	var deck: Array[Dictionary] = []
	var rng: RandomNumberGenerator
	if RunManager.has_active_run():
		# 从背包中随机抽取牌放到本回合牌桌（最多20张，保证分数足够过关）
		var table_count: int = int(min(RunManager.deck.size(), 20))
		var shuffled := RunManager.deck.duplicate(true)
		shuffled.shuffle()
		for i in range(table_count):
			deck.append(shuffled[i])
			_active_card_ids.append(String(shuffled[i].get("cardId", "")))
		_remember_round_max_points(deck)
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
	_update_score_label()
	_update_score_bar()
	_update_combo_label()
	_update_timer_bar()
	status_label.text = "请选择两张可点击的相同牌。"


func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(game_panel, WhatajongUI.COLOR_DOT, Color(0.97, 0.94, 0.86, 0.86), 30, 22)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(restart_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(save_exit_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(back_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_button(restart_button, WhatajongUI.COLOR_CRACK, 0.90)
	WhatajongUI.apply_button(save_exit_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.apply_button(back_button, WhatajongUI.COLOR_DOT, 0.90)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_DOT.darkened(0.38))
	WhatajongUI.tint_body_text(score_label, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	_style_bar_labels()
	_style_score_bar()
	_style_combo_label()
	_style_timer_bar()

	board_shadow.color = Color(0.03, 0.04, 0.05, 0.24)
	board_surface.color = Color(0.20, 0.40, 0.34, 0.94)
	board_inset.color = Color(0.28, 0.50, 0.42, 0.50)
	board_glow.color = Color(0.84, 0.96, 0.86, 0.14)




func _style_bar_labels() -> void:
	var label_color := Color(0.88, 0.82, 0.68, 0.95)
	for lbl: Label in [score_bar_label, timer_bar_label]:
		lbl.add_theme_color_override("font_color", label_color)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _style_score_bar() -> void:
	score_bar.tooltip_text = "分数进度：已有分 / 过关分数"
	# 背景：深色圆角条
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.14, 0.16, 0.45)
	bg_style.corner_radius_top_left = 7
	bg_style.corner_radius_top_right = 7
	bg_style.corner_radius_bottom_right = 7
	bg_style.corner_radius_bottom_left = 7
	bg_style.content_margin_top = 1
	bg_style.content_margin_bottom = 1
	bg_style.content_margin_left = 3
	bg_style.content_margin_right = 3
	score_bar.add_theme_stylebox_override("background", bg_style)

	# 填充：温暖琥珀色（进度条代表得分进度）
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.78, 0.58, 0.22, 0.88)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	fill_style.content_margin_top = 1
	fill_style.content_margin_bottom = 1
	fill_style.content_margin_left = 2
	fill_style.content_margin_right = 2
	score_bar.add_theme_stylebox_override("fill", fill_style)


func _style_combo_label() -> void:
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_color_override("font_color", Color(0.90, 0.65, 0.15))
	combo_label.add_theme_font_size_override("font_size", 20)
	combo_label.visible = false


func _style_timer_bar() -> void:
	timer_bar.tooltip_text = "时间压力：预计结算分 / 过关分数"
	# 背景：深色圆角条
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.14, 0.16, 0.55)
	bg_style.corner_radius_top_left = 7
	bg_style.corner_radius_top_right = 7
	bg_style.corner_radius_bottom_right = 7
	bg_style.corner_radius_bottom_left = 7
	bg_style.content_margin_top = 1
	bg_style.content_margin_bottom = 1
	bg_style.content_margin_left = 3
	bg_style.content_margin_right = 3
	timer_bar.add_theme_stylebox_override("background", bg_style)

	# 填充：金色渐变（初始，运行时会在 _update_timer_bar 中根据比例变色）
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.72, 0.28, 0.92)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	fill_style.content_margin_top = 1
	fill_style.content_margin_bottom = 1
	fill_style.content_margin_left = 2
	fill_style.content_margin_right = 2
	timer_bar.add_theme_stylebox_override("fill", fill_style)


func _update_timer_bar() -> void:
	if not RunManager.has_active_run():
		timer_bar.visible = false
		return

	timer_bar.visible = true
	var round := RunManager.get_round()
	var objective := int(round.get("pointObjective", 0))
	var points := int(game_state.get("points", 0))
	var timer_points := float(round.get("timerPoints", 0.0))

	# 计算时间进度比例：基于"预计结算分"相对目标分
	# ratio = (estimated_total / objective)，1.0 = 刚好达标，>1.0 充裕，<1.0 紧张
	if objective <= 0 or timer_points <= 0:
		timer_bar.value = 100.0
		return

	var elapsed: float = float(game_state.get("time", 0.0))
	var penalty := elapsed * timer_points
	var estimated_total := float(points - penalty)
	var ratio := clampf(estimated_total / float(objective), 0.0, 2.0)

	# 将 ratio 映射到 0-100 进度条值（1.0 → 50%，2.0 → 100%）
	var bar_value := ratio * 50.0
	timer_bar.value = clampf(bar_value, 0.0, 100.0)

	# 根据比例变色：绿 → 黄 → 红
	var fill := timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		if ratio >= 1.2:
			# 充裕：翡翠绿
			fill.bg_color = Color(0.30, 0.68, 0.42, 0.92)
		elif ratio >= 0.8:
			# 稳健：金色
			fill.bg_color = Color(0.85, 0.72, 0.28, 0.92)
		elif ratio >= 0.5:
			# 紧张：橙色
			fill.bg_color = Color(0.90, 0.50, 0.18, 0.92)
		else:
			# 危险：红色闪烁
			var pulse := 0.7 + 0.3 * sin(elapsed * 4.0)
			fill.bg_color = Color(0.88 * pulse, 0.18, 0.12, 0.92)


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
	var first_tile := GameLoop._find_selected_tile(tile_db)
	var wind_direction := _get_wind_direction_for_tile(tile)
	var motion_snapshot := _snapshot_live_tile_views()
	var result := GameLoop.select_tile(tile_db, game_state, tile_id)
	var motion_map := _build_tile_motion_map(motion_snapshot)
	_refresh_tiles_state(motion_map)
	if String(result.get("kind", "")) == "matched" and wind_direction != Vector2.ZERO:
		_play_wind_gust(wind_direction)
	_play_result_feedback(result, first_tile, tile_id)
	_status_from_result(result)
	_update_score_label()
	_update_score_bar()
	_update_combo_label()
	if String(game_state.get("end_condition", "")) != "":
		_handle_round_end()


func _status_from_result(result: Dictionary) -> void:
	var kind := String(result.get("kind", ""))
	var end_condition := String(game_state.get("end_condition", ""))
	if end_condition == "empty-board":
		status_label.text = "牌局已清空，正在进入结算..."
		return
	if end_condition == "no-pairs":
		status_label.text = "没有可消对，正在进入结算..."
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


func _apply_tile_visual(tile_id: String, motion_map: Dictionary = {}) -> void:
	if not tile_nodes.has(tile_id) or not tile_db.has(tile_id):
		return

	var tile_node := _get_live_tile_node(tile_id)
	if tile_node == null:
		return

	var tile: Dictionary = tile_db[tile_id]
	if bool(tile["deleted"]):
		_cancel_tile_motion(tile_id)
		if tile_node.visible:
			tile_node.play_remove()
		return

	var card_id := String(tile["card_id"])
	var material_name := String(tile.get("material", "bone"))
	var scale := _get_layout_scale()
	var base_scale := maxf(1.0, scale)
	tile_node.visible = true
	# 只在牌面数据变化时才重新 setup，避免每帧/每次点击都重绘所有牌
	if tile_node.tile_type != card_id or tile_node.tile_material != material_name:
		tile_node.setup(tile_id, card_id, _get_icon(card_id), material_name)
	tile_node.set_base_scale(Vector2(base_scale, base_scale))

	var free := TileRules.is_free(tile_db, tile)
	tile_node.set_clickable(free)
	tile_node.set_selected(bool(tile["selected"]))
	var target_position := _to_screen_position(tile)
	if motion_map.has(tile_id):
		var motion: Dictionary = motion_map[tile_id]
		var source_position: Vector2 = motion["from"]
		_play_tile_motion(tile_id, tile_node, source_position, target_position)
	else:
		_cancel_tile_motion(tile_id)
		tile_node.position = target_position
	tile_node.z_index = int(tile["z"]) * 100 + int(tile["x"]) + int(tile["y"]) * 2


func _refresh_tiles_state(motion_map: Dictionary = {}) -> void:
	for tile_id in tile_nodes.keys():
		_apply_tile_visual(String(tile_id), motion_map)


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
	_cancel_tile_motion(tile_id)


func _snapshot_live_tile_views() -> Dictionary:
	var snapshot: Dictionary = {}
	for tile_id_value in tile_db.keys():
		var tile_id := String(tile_id_value)
		var tile: Dictionary = tile_db[tile_id]
		if bool(tile.get("deleted", false)):
			continue
		var tile_node := _get_live_tile_node(tile_id)
		if tile_node == null:
			continue
		snapshot[tile_id] = {
			"position": tile_node.position,
			"x": int(tile["x"]),
			"y": int(tile["y"]),
			"z": int(tile["z"]),
		}
	return snapshot


func _build_tile_motion_map(snapshot: Dictionary) -> Dictionary:
	var motion_map: Dictionary = {}
	var has_grid_motion := false
	for tile_id in snapshot.keys():
		if not tile_db.has(tile_id):
			continue
		var tile: Dictionary = tile_db[tile_id]
		if bool(tile.get("deleted", false)):
			continue
		var before: Dictionary = snapshot[tile_id]
		if int(before["x"]) != int(tile["x"]) or int(before["y"]) != int(tile["y"]) or int(before["z"]) != int(tile["z"]):
			has_grid_motion = true
			break

	if not has_grid_motion:
		return motion_map

	for tile_id in snapshot.keys():
		if not tile_db.has(tile_id):
			continue
		var tile: Dictionary = tile_db[tile_id]
		if bool(tile.get("deleted", false)):
			continue
		var before_entry: Dictionary = snapshot[tile_id]
		var source: Vector2 = before_entry["position"]
		var target := _to_screen_position(tile)
		if source.distance_squared_to(target) > 1.0:
			motion_map[tile_id] = {"from": source}
	return motion_map


func _play_tile_motion(tile_id: String, tile_node: Tile, source: Vector2, target: Vector2) -> void:
	_cancel_tile_motion(tile_id)
	tile_node.position = source

	var offset := target - source
	if offset.length_squared() <= 1.0:
		tile_node.position = target
		return

	var overshoot := offset.normalized() * minf(WIND_OVERSHOOT_PX, offset.length() * 0.32)
	var previous_modulate := tile_node.modulate
	tile_node.modulate = previous_modulate.lerp(Color(1.0, 0.96, 0.78, previous_modulate.a), 0.45)

	var motion_tween := create_tween()
	tile_motion_tweens[tile_id] = motion_tween
	motion_tween.tween_property(tile_node, "position", target + overshoot, WIND_PUSH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion_tween.parallel().tween_property(tile_node, "modulate", previous_modulate, WIND_PUSH_DURATION + WIND_SETTLE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(tile_node, "position", target, WIND_SETTLE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion_tween.finished.connect(_on_tile_motion_finished.bind(tile_id, tile_node, target, previous_modulate))


func _on_tile_motion_finished(tile_id: String, tile_node: Tile, target: Vector2, target_modulate: Color) -> void:
	if tile_motion_tweens.has(tile_id):
		tile_motion_tweens.erase(tile_id)
	if is_instance_valid(tile_node):
		tile_node.position = target
		tile_node.modulate = target_modulate


func _cancel_tile_motion(tile_id: String) -> void:
	var tween = tile_motion_tweens.get(tile_id, null)
	if tween != null and (tween as Tween).is_valid():
		(tween as Tween).kill()
	tile_motion_tweens.erase(tile_id)


func _kill_tile_motion_tweens() -> void:
	for tween_value in tile_motion_tweens.values():
		var tween := tween_value as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	tile_motion_tweens.clear()


func _get_wind_direction_for_tile(tile: Dictionary) -> Vector2:
	var card := CardData.get_card_by_id(String(tile.get("card_id", "")))
	if String(card.get("suit", "")) != "wind":
		return Vector2.ZERO

	match String(card.get("rank", "")):
		"n":
			return Vector2.UP
		"s":
			return Vector2.DOWN
		"e":
			return Vector2.RIGHT
		"w":
			return Vector2.LEFT
		_:
			return Vector2.ZERO


func _play_wind_gust(direction: Vector2) -> void:
	if wind_gust_overlay == null or not is_instance_valid(wind_gust_overlay):
		return
	wind_gust_overlay.call("play", direction)


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
	if _round_end_pending:
		return
	_round_end_pending = true
	if not RunManager.has_active_run():
		return
	var result := RunManager.evaluate_round(game_state)
	if bool(result.get("win", false)):
		status_label.text = "通关成功，正在进入结算..."
	else:
		status_label.text = "未达成目标，正在进入结算..."
	_update_score_label()

	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or not RunManager.has_active_run():
		return
	RunManager.enter_stage(RunManager.STAGE_SETTLEMENT)


func _apply_round_header() -> void:
	if not RunManager.has_active_run():
		return
	var round := RunManager.get_round()
	var round_id := int(RunManager.run.get("round", 1))
	title_label.text = "第 %d 回合" % round_id
	_update_score_label()


func _update_score_label() -> void:
	var points := int(game_state.get("points", 0))
	if not RunManager.has_active_run():
		score_label.text = "已有分数：%d" % points
		return

	var round := RunManager.get_round()
	var objective := int(round.get("pointObjective", 0))
	var timer_points := float(round.get("timerPoints", 0.0))
	var penalty := float(game_state.get("time", 0.0)) * timer_points
	var estimated_total := int(points - penalty)
	score_label.text = "已有分数：%d / 过关分数：%d / 预计结算：%d" % [
		points,
		objective,
		estimated_total,
	]


func _update_score_bar() -> void:
	if not RunManager.has_active_run():
		score_bar.visible = false
		return

	score_bar.visible = true
	var points := int(game_state.get("points", 0))
	var round := RunManager.get_round()
	var objective := int(round.get("pointObjective", 0))

	if objective <= 0:
		score_bar.value = 100.0
		return

	var ratio := clampf(float(points) / float(objective), 0.0, 1.5)
	score_bar.value = ratio * 100.0

	# 根据进度变色：红 → 橙 → 琥珀 → 翡翠
	var fill := score_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		if ratio >= 1.0:
			# 达标：翡翠绿
			fill.bg_color = Color(0.30, 0.68, 0.42, 0.90)
		elif ratio >= 0.6:
			# 进展良好：琥珀金
			fill.bg_color = Color(0.78, 0.58, 0.22, 0.88)
		elif ratio >= 0.3:
			# 偏低：暖橙
			fill.bg_color = Color(0.85, 0.48, 0.18, 0.88)
		else:
			# 危险：暗红
			fill.bg_color = Color(0.75, 0.22, 0.15, 0.88)


func _update_combo_label() -> void:
	var dragon_run: Dictionary = game_state.get("dragon_run", {}) as Dictionary
	var phoenix_run: Dictionary = game_state.get("phoenix_run", {}) as Dictionary
	var dragon_combo := int(dragon_run.get("combo", 0))
	var phoenix_combo := int(phoenix_run.get("combo", 0))

	if dragon_combo <= 0 and phoenix_combo <= 0:
		combo_label.visible = false
		return

	combo_label.visible = true
	var parts: Array[String] = []
	if dragon_combo > 0:
		var color_name := String(dragon_run.get("color", ""))
		parts.append("龙×%d" % dragon_combo)
	if phoenix_combo > 0:
		parts.append("凤×%d" % phoenix_combo)

	var multiplier := maxi(1, dragon_combo + phoenix_combo * 2)
	combo_label.text = "🔥 %s  倍率 ×%d" % ["  ".join(parts), multiplier]

	# 高倍率时变色提示
	if multiplier >= 5:
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.20))
	elif multiplier >= 3:
		combo_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.12))
	else:
		combo_label.add_theme_color_override("font_color", Color(0.90, 0.65, 0.15))











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


func _setup_wind_gust_overlay() -> void:
	wind_gust_overlay = WIND_GUST_OVERLAY_SCRIPT.new() as Control
	wind_gust_overlay.name = "WindGustOverlay"
	wind_gust_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind_gust_overlay.z_index = 500
	board_container.add_child(wind_gust_overlay)
	_fit_control_to_parent(wind_gust_overlay)


func _fit_control_to_parent(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


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


func _play_result_feedback(result: Dictionary, first_tile: Dictionary = {}, second_tile_id: String = "") -> void:
	match String(result.get("kind", "")):
		"matched":
			_play_match_sound()
			_spawn_match_particles(first_tile, second_tile_id)
		"mismatch":
			pass
		"selected-first":
			_spawn_select_particles(second_tile_id)
			pass
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
	if wind_gust_overlay != null and is_instance_valid(wind_gust_overlay):
		_fit_control_to_parent(wind_gust_overlay)
	if _ambient_particles != null:
		_ambient_particles.position = board_container.size * 0.5
	if not tile_db.is_empty():
		_refresh_tiles_state()


func _setup_ambient_particles() -> void:
	_ambient_particles = AMBIENT_PARTICLES.instantiate() as CPUParticles2D
	board_container.add_child(_ambient_particles)
	_ambient_particles.position = board_container.size * 0.5
	_ambient_particles.z_index = -10


func _spawn_match_particles(first_tile: Dictionary, second_tile_id: String) -> void:
	if first_tile.is_empty() or not tile_db.has(second_tile_id):
		return
	var pos1 := _to_screen_position(first_tile)
	var pos2 := _to_screen_position(tile_db[second_tile_id])
	var mid := (pos1 + pos2) * 0.5 + Vector2(41, 60)
	var particles := MATCH_PARTICLES.instantiate() as CPUParticles2D
	tile_layer.add_child(particles)
	particles.position = mid
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _spawn_select_particles(tile_id: String) -> void:
	if not tile_db.has(tile_id):
		return
	var pos := _to_screen_position(tile_db[tile_id]) + Vector2(41, 60)
	var particles := SELECT_PARTICLES.instantiate() as CPUParticles2D
	tile_layer.add_child(particles)
	particles.position = pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _on_save_exit_button_pressed() -> void:
	SaveManager.save_game(tile_db, game_state)
	status_label.text = "游戏已保存，返回主菜单..."
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")


func _setup_inventory() -> void:
	_inventory_popup = InventoryPopup.new()
	_inventory_popup.create(self)

	var inv_button := Button.new()
	inv_button.text = "背包"
	inv_button.custom_minimum_size = Vector2(90, 38)
	WhatajongUI.apply_button(inv_button, WhatajongUI.COLOR_DOT, 0.88)
	inv_button.pressed.connect(_on_inventory_pressed)

	inv_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv_button.offset_left = -110
	inv_button.offset_top = 10
	inv_button.offset_right = -10
	inv_button.offset_bottom = 50
	game_panel.add_child(inv_button)


func _on_inventory_pressed() -> void:
	RunManager.ensure_deck_initialized()
	_inventory_popup.show_inventory(RunManager.deck, _active_card_ids)


func _load_saved_board() -> void:
	# 旧存档可能没有 deck 数据，强制补全
	if RunManager.deck.is_empty():
		RunManager.deck = DeckState.create_initial_deck()
	RunManager.ensure_deck_initialized()
	var save_data := SaveManager.load_game()
	if save_data.is_empty():
		_setup_new_round()
		return

	# 恢复 RunManager 的 run/deck/levels（修复继续游戏数据丢失的 Bug）
	SaveManager.restore_run_manager(save_data)

	# 清理旧牌
	for child in tile_layer.get_children():
		child.queue_free()
	tile_db.clear()
	tile_nodes.clear()
	icon_cache.clear()

	# 恢复 game_state
	var saved_state: Dictionary = save_data.get("game_state", {})
	game_state = {
		"points": int(saved_state.get("points", 0)),
		"coins": int(saved_state.get("coins", 0)),
		"time": float(saved_state.get("time", 0.0)),
		"end_condition": String(saved_state.get("end_condition", "")),
		"dragon_run": saved_state.get("dragon_run", {}),
		"phoenix_run": saved_state.get("phoenix_run", {}),
		"temporary_material": String(saved_state.get("temporary_material", "")),
		"enabled_modules": saved_state.get("enabled_modules", GameLoop.MODULE_ORDER.duplicate()),
	}

	# 恢复 tile_db
	var saved_tile_db: Dictionary = save_data.get("tile_db", {})
	for tile_id in saved_tile_db.keys():
		var tile: Dictionary = saved_tile_db[tile_id]
		tile_db[tile_id] = {
			"id": String(tile.get("id", tile_id)),
			"card_id": String(tile.get("card_id", "bam1")),
			"material": String(tile.get("material", "bone")),
			"x": int(tile.get("x", 0)),
			"y": int(tile.get("y", 0)),
			"z": int(tile.get("z", 0)),
			"deleted": bool(tile.get("deleted", false)),
			"selected": bool(tile.get("selected", false)),
		}

	# 存档恢复时补齐 roundMaxPoints，确保目标分数可通关。
	_remember_round_max_points_from_tile_db()

	# 重建牌节点
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
	_update_score_label()
	_update_score_bar()
	_update_combo_label()
	_update_timer_bar()

	if RunManager.has_active_run():
		var round := RunManager.get_round()
		var round_id := int(RunManager.run.get("round", 1))
		var objective := int(round.get("pointObjective", 0))
		title_label.text = "第 %d 回合" % round_id
		status_label.text = "继续游戏，当前分数：%d" % int(game_state["points"])
	else:
		status_label.text = "继续游戏，当前分数：%d" % int(game_state["points"])


func _remember_round_max_points(table_deck: Array[Dictionary]) -> void:
	if not RunManager.has_active_run():
		return
	var run_id := String(RunManager.run.get("runId", ""))
	if run_id == "":
		return
	var round_id := int(RunManager.run.get("round", 1))
	var key := "%s-%d" % [run_id, round_id]
	var map = RunManager.run.get("roundMaxPoints", {})
	var max_points_map: Dictionary = map if map is Dictionary else {}
	if max_points_map.has(key):
		return
	max_points_map[key] = _estimate_table_max_points(table_deck)
	RunManager.run["roundMaxPoints"] = max_points_map


func _estimate_table_max_points(table_deck: Array[Dictionary]) -> int:
	var dummy_state := {
		"dragon_run": {},
		"phoenix_run": {},
		"temporary_material": "",
	}
	var total := 0
	for d in table_deck:
		var card_id := String(d.get("cardId", ""))
		if card_id == "":
			card_id = String(d.get("card_id", ""))
		var material := String(d.get("material", "bone"))
		var tile := {"card_id": card_id, "material": material}
		total += GameLoop.get_points(tile, dummy_state) * 2
	return total


func _remember_round_max_points_from_tile_db() -> void:
	if not RunManager.has_active_run():
		return
	var run_id := String(RunManager.run.get("runId", ""))
	if run_id == "":
		return
	var round_id := int(RunManager.run.get("round", 1))
	var key := "%s-%d" % [run_id, round_id]
	var map = RunManager.run.get("roundMaxPoints", {})
	var max_points_map: Dictionary = map if map is Dictionary else {}
	if max_points_map.has(key):
		return
	max_points_map[key] = _estimate_tile_db_max_points(tile_db)
	RunManager.run["roundMaxPoints"] = max_points_map


func _estimate_tile_db_max_points(db: Dictionary) -> int:
	var dummy_state := {
		"dragon_run": {},
		"phoenix_run": {},
		"temporary_material": "",
	}
	var total := 0
	for v in db.values():
		if not (v is Dictionary):
			continue
		var t: Dictionary = v
		var card_id := String(t.get("card_id", ""))
		var material := String(t.get("material", "bone"))
		var tile := {"card_id": card_id, "material": material}
		total += GameLoop.get_points(tile, dummy_state)
	return total
