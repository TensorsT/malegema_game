extends Control

## PvPBoard — 联机对战棋盘控制器
## 房主权威：所有输入请求在房主验证后同步到双方

const TILE_SCENE := preload("res://scene/Tile.tscn")
const WIND_GUST_OVERLAY_SCRIPT := preload("res://scripts/wind_gust_overlay.gd")
const CLICK_STREAM := preload("res://sounds/click.mp3")
const MATCH_STREAM := preload("res://sounds/gemstone.mp3")
const MATCH_PARTICLES := preload("res://scene/MatchParticles.tscn")
const AMBIENT_PARTICLES := preload("res://scene/AmbientParticles.tscn")

const STEP_X := 40
const STEP_Y := 54
const Z_OFFSET_X := 10
const Z_OFFSET_Y := 16
const TILE_DRAW_SIZE := Vector2(82, 120)
const BOARD_PADDING := Vector2(54, 42)
const MAX_LAYOUT_SCALE := 1.65

const ATTACKS := {
	"mist": {"name": "迷雾", "cost": 2},
	"wind": {"name": "乱风", "cost": 3},
	"freeze": {"name": "冰冻", "cost": 4},
	"flame": {"name": "烈焰", "cost": 5},
}

@onready var board_container: Control = $GamePanel/VBoxContainer/BoardContainer
@onready var tile_layer: Control = $GamePanel/VBoxContainer/BoardContainer/TileLayer
@onready var game_panel: Panel = $GamePanel
@onready var title_label: Label = $GamePanel/VBoxContainer/TitleLabel
@onready var score_label: Label = $GamePanel/VBoxContainer/ScoreRow/ScoreLabel
@onready var opponent_score_label: Label = $GamePanel/VBoxContainer/ScoreRow/OpponentScoreLabel
@onready var status_label: Label = $GamePanel/VBoxContainer/StatusLabel
@onready var countdown_label: Label = $GamePanel/VBoxContainer/CountdownLabel
@onready var round_info_label: Label = $GamePanel/VBoxContainer/RoundInfoLabel
@onready var board_shadow: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardShadow
@onready var board_surface: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardSurface
@onready var board_inset: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardInset
@onready var board_glow: ColorRect = $GamePanel/VBoxContainer/BoardContainer/BoardGlow
@onready var back_button: Button = $GamePanel/VBoxContainer/ActionRow/BackButton
@onready var surrender_button: Button = $GamePanel/VBoxContainer/ActionRow/SurrenderButton
@onready var attack_row: HBoxContainer = $GamePanel/VBoxContainer/AttackRow

var tile_db: Dictionary = {}
var tile_nodes: Dictionary = {}
var icon_cache: Dictionary = {}
var click_player: AudioStreamPlayer
var match_player: AudioStreamPlayer
var wind_gust_overlay: Control
var _ambient_particles: CPUParticles2D

var _my_peer_id: int = 0
var _opponent_peer_id: int = 0
var _round_ended := false
var _countdown_remaining := 3
var _selected_tile_id := ""
var _attack_buttons: Array[Button] = []
var _frozen_until_sec := 0.0
var _mist_until_sec := 0.0
var _last_frozen_state := false


func _ready() -> void:
	_my_peer_id = PvPNetwork.get_local_peer_id()
	_opponent_peer_id = PvPNetwork.get_remote_peer_id()

	_apply_whatajong_ui()
	_setup_audio()
	_setup_wind_gust_overlay()
	_setup_ambient_particles()
	_setup_attack_bar()

	board_container.resized.connect(_on_board_container_resized)
	_on_board_container_resized()

	PvPState.state_changed.connect(_on_state_changed)
	PvPState.phase_changed.connect(_on_phase_changed)
	PvPState.score_updated.connect(_on_score_updated)
	PvPState.energy_updated.connect(_on_energy_updated)
	PvPNetwork.peer_disconnected.connect(_on_peer_disconnected)
	PvPNetwork.server_disconnected.connect(_on_server_disconnected)

	_update_ui()
	status_label.text = "等待房主开始..."

	if PvPNetwork.is_host() and PvPState.phase == PvPState.PHASE_WAITING:
		_host_start_round()


func _exit_tree() -> void:
	if PvPState.state_changed.is_connected(_on_state_changed):
		PvPState.state_changed.disconnect(_on_state_changed)
	if PvPState.phase_changed.is_connected(_on_phase_changed):
		PvPState.phase_changed.disconnect(_on_phase_changed)
	if PvPState.score_updated.is_connected(_on_score_updated):
		PvPState.score_updated.disconnect(_on_score_updated)
	if PvPState.energy_updated.is_connected(_on_energy_updated):
		PvPState.energy_updated.disconnect(_on_energy_updated)
	if PvPNetwork.peer_disconnected.is_connected(_on_peer_disconnected):
		PvPNetwork.peer_disconnected.disconnect(_on_peer_disconnected)
	if PvPNetwork.server_disconnected.is_connected(_on_server_disconnected):
		PvPNetwork.server_disconnected.disconnect(_on_server_disconnected)


func _process(_delta: float) -> void:
	var frozen_now := _now_sec() < _frozen_until_sec
	if frozen_now != _last_frozen_state:
		_last_frozen_state = frozen_now
		_refresh_tiles_state()
		_update_ui()
	if _mist_until_sec > 0.0 and _now_sec() >= _mist_until_sec:
		_clear_mist_effect()


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


## ── 房主流程 ──────────────────────────────────────────
func _host_start_round() -> void:
	if not PvPNetwork.is_host():
		return

	PvPState.reset_for_new_round()
	PvPState.board_seed = randi()
	_round_ended = false
	_selected_tile_id = ""
	_frozen_until_sec = 0.0
	_clear_mist_effect()

	_rpc_start_round.rpc(PvPState.board_seed, PvPState.round_number)


@rpc("authority", "call_local", "reliable")
func _rpc_start_round(seed_value: int, round_number: int) -> void:
	PvPState.board_seed = seed_value
	PvPState.round_number = round_number
	PvPState.phase = PvPState.PHASE_COUNTDOWN
	_round_ended = false
	_selected_tile_id = ""
	_frozen_until_sec = 0.0
	_clear_mist_effect()
	_build_board_local()
	_start_countdown_local()
	_update_ui()


func _start_countdown_local() -> void:
	_countdown_remaining = 3
	countdown_label.show()
	_countdown_tick()


func _countdown_tick() -> void:
	if _countdown_remaining > 0:
		countdown_label.text = "%d" % _countdown_remaining
		countdown_label.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_property(countdown_label, "modulate:a", 0.3, 0.8)
		tween.tween_callback(func() -> void:
			_countdown_remaining -= 1
			_countdown_tick()
		)
		return

	countdown_label.text = "开始！"
	countdown_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(countdown_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		countdown_label.hide()
		if PvPNetwork.is_host():
			PvPState.start_playing()
			_rpc_set_playing.rpc()
	)


@rpc("authority", "call_local", "reliable")
func _rpc_set_playing() -> void:
	PvPState.phase = PvPState.PHASE_PLAYING
	status_label.text = "对战开始！抢牌消除！"
	_update_ui()


## ── 棋盘生成 / 同步 ───────────────────────────────────
func _build_board_local() -> void:
	tile_db.clear()
	tile_nodes.clear()
	icon_cache.clear()

	for child in tile_layer.get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.set_seed(PvPState.board_seed)
	var deck := _generate_pvp_deck()
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
		tile_nodes[tile_id] = tile_node

	_refresh_tiles_state()


func _generate_pvp_deck() -> Array[Dictionary]:
	var all_cards := CardData.get_all_cards()
	var rng := RandomNumberGenerator.new()
	rng.set_seed(PvPState.board_seed + 1)

	var base_pool: Array[Dictionary] = []
	var special_pool: Array[Dictionary] = []
	for card in all_cards:
		var suit := String(card.get("suit", ""))
		if suit in ["bam", "crack", "dot"]:
			base_pool.append(card)
		elif suit in ["dragon", "gem", "phoenix", "element"]:
			special_pool.append(card)

	base_pool.shuffle()
	special_pool.shuffle()

	var deck: Array[Dictionary] = []
	var base_pairs := min(10, base_pool.size())
	var special_pairs := min(6, special_pool.size())
	for i in range(base_pairs):
		deck.append(base_pool[i])
		deck.append(base_pool[i])
	for i in range(special_pairs):
		deck.append(special_pool[i])
		deck.append(special_pool[i])
	return deck


@rpc("authority", "call_local", "reliable")
func _rpc_sync_snapshot(
	board_state: Dictionary,
	locked_state: Dictionary,
	score_state: Dictionary,
	energy_state: Dictionary,
	cooldown_state: Dictionary
) -> void:
	tile_db = board_state.duplicate(true)
	PvPState.locked_tiles = locked_state.duplicate(true)
	PvPState.scores = score_state.duplicate(true)
	PvPState.energies = energy_state.duplicate(true)
	PvPState.attack_cooldowns = cooldown_state.duplicate(true)
	_refresh_tiles_state()
	_update_ui()


func _host_push_snapshot() -> void:
	if not PvPNetwork.is_host():
		return
	_rpc_sync_snapshot.rpc(tile_db, PvPState.locked_tiles, PvPState.scores, PvPState.energies, PvPState.attack_cooldowns)


## ── 选牌逻辑（客户端 → 房主）──────────────────────────
func _on_tile_pressed(tile_id: String) -> void:
	if PvPState.phase != PvPState.PHASE_PLAYING or _round_ended:
		return
	if _now_sec() < _frozen_until_sec:
		status_label.text = "你被冰冻，暂时无法操作"
		return
	if not tile_db.has(tile_id):
		return

	var tile: Dictionary = tile_db[tile_id]
	if bool(tile.get("deleted", false)):
		return
	if not TileRules.is_free(tile_db, tile):
		var bad_node := tile_nodes.get(tile_id) as Tile
		if bad_node != null:
			bad_node.play_invalid_feedback()
		return
	if PvPState.is_tile_locked(tile_id) and PvPState.get_tile_locker(tile_id) != _my_peer_id:
		status_label.text = "这张牌已被对手锁定"
		return

	if click_player != null:
		click_player.pitch_scale = randf_range(0.95, 1.06)
		click_player.play()

	if PvPNetwork.is_host():
		_handle_select_request(_my_peer_id, tile_id)
	else:
		_request_select_tile.rpc_id(1, tile_id)


@rpc("any_peer", "reliable")
func _request_select_tile(tile_id: String) -> void:
	if not PvPNetwork.is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_handle_select_request(sender_id, tile_id)


func _handle_select_request(peer_id: int, tile_id: String) -> void:
	if _round_ended or PvPState.phase != PvPState.PHASE_PLAYING:
		return
	if not tile_db.has(tile_id):
		return

	var tile: Dictionary = tile_db[tile_id]
	if bool(tile.get("deleted", false)):
		return
	if not TileRules.is_free(tile_db, tile):
		return
	if PvPState.is_tile_locked(tile_id) and PvPState.get_tile_locker(tile_id) != peer_id:
		return

	var first_tile_id := _find_selected_tile_for_peer(peer_id)
	if first_tile_id == tile_id:
		tile["selected"] = false
		tile_db[tile_id] = tile
		PvPState.unlock_tile(tile_id)
		_selected_tile_id = ""
		_host_push_snapshot()
		return

	if first_tile_id == "":
		tile["selected"] = true
		tile_db[tile_id] = tile
		PvPState.lock_tile(tile_id, peer_id)
		if peer_id == _my_peer_id:
			_selected_tile_id = tile_id
		_host_push_snapshot()
		return

	var first_tile: Dictionary = tile_db.get(first_tile_id, {})
	if first_tile.is_empty():
		PvPState.unlock_all_for_peer(peer_id)
		_host_push_snapshot()
		return

	if GameLoop.cards_match(String(first_tile["card_id"]), String(tile["card_id"])):
		first_tile["deleted"] = true
		first_tile["selected"] = false
		tile["deleted"] = true
		tile["selected"] = false
		tile_db[first_tile_id] = first_tile
		tile_db[tile_id] = tile
		PvPState.unlock_all_for_peer(peer_id)

		var game_state := {"dragon_run": {}, "phoenix_run": {}, "temporary_material": ""}
		var points := int(GameLoop.get_points(first_tile, game_state) + GameLoop.get_points(tile, game_state))
		PvPState.add_score(peer_id, points)
		PvPState.add_energy(peer_id, 1)
		PvPState.tiles_cleared[peer_id] = int(PvPState.tiles_cleared.get(peer_id, 0)) + 2
		PvPState.record_match_time(peer_id)
		PvPState.record_action(peer_id)

		_host_push_snapshot()
		_rpc_match_feedback.rpc(peer_id, first_tile_id, tile_id, points)

		var result := PvPState.check_round_end(tile_db)
		if bool(result.get("ended", false)):
			_host_finish_round(int(result.get("winner_id", 0)), String(result.get("reason", "")))
	else:
		first_tile["selected"] = false
		tile["selected"] = false
		tile_db[first_tile_id] = first_tile
		tile_db[tile_id] = tile
		PvPState.unlock_all_for_peer(peer_id)
		if peer_id == _my_peer_id:
			_selected_tile_id = ""
		_host_push_snapshot()
		_rpc_mismatch_feedback.rpc(peer_id)


func _find_selected_tile_for_peer(peer_id: int) -> String:
	for tile_id in PvPState.locked_tiles.keys():
		if int(PvPState.locked_tiles[tile_id]) != peer_id:
			continue
		var tile: Dictionary = tile_db.get(String(tile_id), {})
		if bool(tile.get("selected", false)):
			return String(tile_id)
	return ""


@rpc("authority", "call_local", "reliable")
func _rpc_match_feedback(peer_id: int, tile_id1: String, tile_id2: String, points: int) -> void:
	_play_match_feedback(tile_id1, tile_id2)
	if peer_id == _my_peer_id:
		status_label.text = "配对成功 +%d！" % points
	else:
		status_label.text = "对手消除了 +%d！" % points


@rpc("authority", "call_local", "reliable")
func _rpc_mismatch_feedback(peer_id: int) -> void:
	if peer_id == _my_peer_id:
		status_label.text = "配对失败，已重置选择"
	else:
		status_label.text = "对手配对失败"


func _host_finish_round(winner_id: int, reason: String) -> void:
	if not PvPNetwork.is_host() or _round_ended:
		return

	_round_ended = true
	PvPState.resolve_round(winner_id, reason)
	var match_winner := PvPState.check_match_over()
	_rpc_round_end.rpc(winner_id, reason, match_winner, PvPState.match_wins)


@rpc("authority", "call_local", "reliable")
func _rpc_round_end(winner_id: int, reason: String, match_winner_id: int, wins_state: Dictionary) -> void:
	_round_ended = true
	PvPState.match_wins = wins_state.duplicate(true)
	var me_won := winner_id == _my_peer_id
	status_label.text = ("%s（%s）" % ["你赢了！" if me_won else "对手赢了...", reason])
	_update_ui()

	if match_winner_id != 0:
		await get_tree().create_timer(1.3).timeout
		get_tree().change_scene_to_file("res://scene/pvp_result.tscn")
		return

	if PvPNetwork.is_host():
		await get_tree().create_timer(1.6).timeout
		_host_start_round()


## ── 攻击系统 ──────────────────────────────────────────
func _setup_attack_bar() -> void:
	_attack_buttons.clear()
	for child in attack_row.get_children():
		child.queue_free()

	var order := ["mist", "wind", "freeze", "flame"]
	for attack_id in order:
		var info: Dictionary = ATTACKS[attack_id]
		var btn := Button.new()
		btn.text = "%s (%d)" % [String(info.get("name", attack_id)), int(info.get("cost", 0))]
		btn.set_meta("id", attack_id)
		btn.set_meta("cost", int(info.get("cost", 0)))
		btn.set_meta("label", String(info.get("name", attack_id)))
		btn.custom_minimum_size = Vector2(92, 42)
		btn.pressed.connect(_on_attack_pressed.bind(attack_id))
		WhatajongUI.apply_button(btn, WhatajongUI.COLOR_BAM, 0.85)
		WhatajongUI.apply_display_font(btn, WhatajongUI.FONT_SIZE_SMALL)
		attack_row.add_child(btn)
		_attack_buttons.append(btn)


func _on_attack_pressed(attack_id: String) -> void:
	if PvPState.phase != PvPState.PHASE_PLAYING or _round_ended:
		return
	if _now_sec() < _frozen_until_sec:
		status_label.text = "你被冰冻，无法释放技能"
		return

	if PvPNetwork.is_host():
		_handle_attack_request(_my_peer_id, attack_id)
	else:
		_request_attack.rpc_id(1, attack_id)


@rpc("any_peer", "reliable")
func _request_attack(attack_id: String) -> void:
	if not PvPNetwork.is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_handle_attack_request(sender_id, attack_id)


func _handle_attack_request(peer_id: int, attack_id: String) -> void:
	var info: Dictionary = ATTACKS.get(attack_id, {})
	if info.is_empty():
		return
	var cost := int(info.get("cost", 99))
	if PvPState.is_attack_on_cooldown(peer_id):
		_rpc_attack_rejected.rpc_id(peer_id, "技能冷却中")
		return
	if not PvPState.consume_energy(peer_id, cost):
		_rpc_attack_rejected.rpc_id(peer_id, "能量不足")
		return

	PvPState.start_attack_cooldown(peer_id, 5.0)
	PvPState.record_action(peer_id)
	_host_push_snapshot()
	_rpc_attack_effect.rpc(peer_id, attack_id)


@rpc("authority", "reliable")
func _rpc_attack_rejected(reason: String) -> void:
	status_label.text = reason


@rpc("authority", "call_local", "reliable")
func _rpc_attack_effect(peer_id: int, attack_id: String) -> void:
	var is_me := peer_id == _my_peer_id
	status_label.text = "%s 释放了 %s！" % ["你" if is_me else "对手", attack_id]

	match attack_id:
		"mist":
			_play_wind_gust(Vector2.LEFT if is_me else Vector2.RIGHT)
			if not is_me:
				_apply_mist_effect(2.5)
		"wind":
			_play_wind_gust(Vector2.RIGHT if is_me else Vector2.LEFT)
		"freeze":
			if not is_me:
				_frozen_until_sec = _now_sec() + 2.0
				status_label.text = "你被冰冻 2 秒"
		"flame":
			if not is_me:
				status_label.text = "你受到烈焰压制，保持节奏！"


func _apply_mist_effect(duration_sec: float) -> void:
	_mist_until_sec = _now_sec() + duration_sec
	_refresh_tiles_state()


func _clear_mist_effect() -> void:
	_mist_until_sec = 0.0
	_refresh_tiles_state()


func _play_wind_gust(direction: Vector2) -> void:
	if wind_gust_overlay != null and is_instance_valid(wind_gust_overlay):
		wind_gust_overlay.call("play", direction)


## ── 视觉 / 交互 ───────────────────────────────────────
func _play_match_feedback(tile_id1: String, tile_id2: String) -> void:
	if match_player != null:
		match_player.pitch_scale = randf_range(0.94, 1.06)
		match_player.play()

	var pos1 := Vector2.ZERO
	var pos2 := Vector2.ZERO
	if tile_db.has(tile_id1):
		pos1 = _to_screen_position(tile_db[tile_id1])
	if tile_db.has(tile_id2):
		pos2 = _to_screen_position(tile_db[tile_id2])

	var mid := (pos1 + pos2) * 0.5 + Vector2(41, 60)
	var particles := MATCH_PARTICLES.instantiate() as CPUParticles2D
	tile_layer.add_child(particles)
	particles.position = mid
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _refresh_tiles_state() -> void:
	for tile_id in tile_nodes.keys():
		_apply_tile_visual(String(tile_id))


func _apply_tile_visual(tile_id: String) -> void:
	if not tile_nodes.has(tile_id) or not tile_db.has(tile_id):
		return
	var tile: Dictionary = tile_db[tile_id]
	var tile_node := tile_nodes[tile_id] as Tile
	if tile_node == null or not is_instance_valid(tile_node):
		return

	if bool(tile.get("deleted", false)):
		if tile_node.visible:
			tile_node.play_remove()
		return

	var card_id := String(tile["card_id"])
	var material_name := String(tile.get("material", "bone"))
	tile_node.visible = true
	if tile_node.tile_type != card_id or tile_node.tile_material != material_name:
		tile_node.setup(tile_id, card_id, _get_icon(card_id), material_name)

	var free := TileRules.is_free(tile_db, tile)
	tile_node.set_clickable(free and PvPState.phase == PvPState.PHASE_PLAYING and not _round_ended and _now_sec() >= _frozen_until_sec)
	tile_node.set_selected(bool(tile.get("selected", false)) and int(PvPState.get_tile_locker(tile_id)) == _my_peer_id)
	tile_node.position = _to_screen_position(tile)

	var locker := int(PvPState.get_tile_locker(tile_id))
	if locker == 0:
		tile_node.modulate = Color.WHITE
	elif locker == _my_peer_id:
		tile_node.modulate = Color(1.0, 0.95, 0.85, 1.0)
	else:
		tile_node.modulate = Color(0.75, 0.85, 1.0, 0.9)

	if _now_sec() < _mist_until_sec:
		tile_node.modulate = tile_node.modulate * Color(0.72, 0.72, 0.78, 0.65)


func _get_icon(card_id: String) -> Texture2D:
	if icon_cache.has(card_id):
		return icon_cache[card_id]
	var path := "res://tiles/%s.webp" % card_id
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		icon_cache[card_id] = tex
		return tex
	return null


func _to_screen_position(tile: Dictionary) -> Vector2:
	var origin := _get_layout_origin()
	var raw := _to_layout_space(tile)
	var scale := _get_layout_scale()
	return raw * scale + origin


func _to_layout_space(tile: Dictionary) -> Vector2:
	return Vector2(
		float(tile["x"]) * STEP_X - float(tile["z"]) * Z_OFFSET_X,
		float(tile["y"]) * STEP_Y - float(tile["z"]) * Z_OFFSET_Y
	)


func _get_layout_origin() -> Vector2:
	var bounds := _get_layout_bounds()
	var available := board_container.size - BOARD_PADDING * 2.0
	if available.x <= 0 or available.y <= 0:
		return -bounds.position * _get_layout_scale()
	var scale := _get_layout_scale()
	return BOARD_PADDING + (available - bounds.size * scale) * 0.5 - bounds.position * scale


func _get_layout_scale() -> float:
	if tile_db.is_empty():
		return 1.0
	var bounds := _get_layout_bounds()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return 1.0
	var available := board_container.size - BOARD_PADDING * 2.0
	if available.x <= 0 or available.y <= 0:
		return 1.0
	return min(MAX_LAYOUT_SCALE, min(available.x / bounds.size.x, available.y / bounds.size.y))


func _get_layout_bounds() -> Rect2:
	var has := false
	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO
	for tile in tile_db.values():
		var t: Dictionary = tile
		var pos := _to_layout_space(t)
		if not has:
			min_pos = pos
			max_pos = pos + TILE_DRAW_SIZE
			has = true
			continue
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x + TILE_DRAW_SIZE.x)
		max_pos.y = maxf(max_pos.y, pos.y + TILE_DRAW_SIZE.y)
	return Rect2(min_pos, max_pos - min_pos) if has else Rect2(Vector2.ZERO, TILE_DRAW_SIZE)


func _sorted_tiles(db: Dictionary) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for v in db.values():
		tiles.append(v as Dictionary)
	tiles.sort_custom(func(a, b):
		if int(a["z"]) != int(b["z"]):
			return int(a["z"]) < int(b["z"])
		if int(a["y"]) != int(b["y"]):
			return int(a["y"]) < int(b["y"])
		return int(a["x"]) < int(b["x"])
	)
	return tiles


## ── UI / 信号 ─────────────────────────────────────────
func _update_ui() -> void:
	score_label.text = "你：%d 分" % PvPState.get_score(_my_peer_id)
	opponent_score_label.text = "对手：%d 分" % PvPState.get_score(_opponent_peer_id)
	round_info_label.text = "第 %d/%d 局  |  战绩 %d:%d" % [
		max(1, PvPState.round_number), PvPState.BEST_OF,
		int(PvPState.match_wins.get(_my_peer_id, 0)),
		int(PvPState.match_wins.get(_opponent_peer_id, 0)),
	]

	var my_energy := PvPState.get_energy(_my_peer_id)
	var cooling := PvPState.is_attack_on_cooldown(_my_peer_id)
	var frozen := _now_sec() < _frozen_until_sec
	for btn in _attack_buttons:
		var cost := int(btn.get_meta("cost", 99))
		btn.disabled = _round_ended or PvPState.phase != PvPState.PHASE_PLAYING or frozen or cooling or my_energy < cost
		btn.text = "%s (%d)" % [String(btn.get_meta("label", btn.get_meta("id", ""))), cost]


func _on_state_changed() -> void:
	_update_ui()


func _on_score_updated(_peer_id: int, _score: int) -> void:
	_update_ui()


func _on_energy_updated(_peer_id: int, _energy: int) -> void:
	_update_ui()


func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PvPState.PHASE_PLAYING:
		status_label.text = "对战开始！抢牌消除！"


func _on_peer_disconnected(_peer_id: int) -> void:
	if _round_ended:
		return
	_round_ended = true
	status_label.text = "对手已断开，返回大厅..."
	await get_tree().create_timer(1.0).timeout
	PvPNetwork.disconnect_from_network()
	get_tree().change_scene_to_file("res://scene/pvp_lobby.tscn")


func _on_server_disconnected() -> void:
	if _round_ended:
		return
	_round_ended = true
	status_label.text = "与房间断开，返回大厅..."
	await get_tree().create_timer(1.0).timeout
	PvPNetwork.disconnect_from_network()
	get_tree().change_scene_to_file("res://scene/pvp_lobby.tscn")


func _on_board_container_resized() -> void:
	if wind_gust_overlay != null and is_instance_valid(wind_gust_overlay):
		_fit_to_parent(wind_gust_overlay)
	if _ambient_particles != null and is_instance_valid(_ambient_particles):
		_ambient_particles.position = board_container.size * 0.5
	_refresh_tiles_state()


func _on_back_button_pressed() -> void:
	PvPNetwork.disconnect_from_network()
	get_tree().change_scene_to_file("res://scene/pvp_lobby.tscn")


func _on_surrender_button_pressed() -> void:
	if _round_ended:
		return
	status_label.text = "你认输了..."
	if PvPNetwork.is_host():
		_host_finish_round(_opponent_peer_id, "surrender")
	else:
		_request_surrender.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_surrender() -> void:
	if not PvPNetwork.is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var winner := 2 if sender_id == 1 else 1
	_host_finish_round(winner, "surrender")


## ── 音频 / 背景特效 ───────────────────────────────────
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
	wind_gust_overlay = WIND_GUST_OVERLAY_SCRIPT.new()
	wind_gust_overlay.name = "WindGustOverlay"
	wind_gust_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind_gust_overlay.z_index = 500
	board_container.add_child(wind_gust_overlay)
	_fit_to_parent(wind_gust_overlay)


func _setup_ambient_particles() -> void:
	_ambient_particles = AMBIENT_PARTICLES.instantiate()
	board_container.add_child(_ambient_particles)
	_ambient_particles.position = board_container.size * 0.5
	_ambient_particles.z_index = -10


func _fit_to_parent(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


## ── UI 样式 ──────────────────────────────────────────
func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(game_panel, WhatajongUI.COLOR_DOT, Color(0.97, 0.94, 0.86, 0.86), 30, 22)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(back_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(surrender_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_button(back_button, WhatajongUI.COLOR_BAM, 0.90)
	WhatajongUI.apply_button(surrender_button, Color(0.85, 0.25, 0.25), 0.90)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_DOT.darkened(0.38))
	WhatajongUI.tint_body_text(score_label, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(opponent_score_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(round_info_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(countdown_label, Color(0.9, 0.3, 0.2), 72)

	board_shadow.color = Color(0.03, 0.04, 0.05, 0.24)
	board_surface.color = Color(0.20, 0.40, 0.34, 0.94)
	board_inset.color = Color(0.28, 0.50, 0.42, 0.50)
	board_glow.color = Color(0.84, 0.96, 0.86, 0.14)

	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
