extends Control

## PvPTutorial — 联机对战教程
## 复用 tutorial_board.gd 的步进式教学框架

@onready var game_panel: Panel = $GamePanel
@onready var title_label: Label = $GamePanel/VBoxContainer/TitleLabel
@onready var status_label: Label = $GamePanel/VBoxContainer/StatusLabel
@onready var board_container: Control = $GamePanel/VBoxContainer/BoardContainer
@onready var tile_layer: Control = $GamePanel/VBoxContainer/BoardContainer/TileLayer
@onready var next_button: Button = $GamePanel/VBoxContainer/ButtonRow/NextButton
@onready var skip_button: Button = $GamePanel/VBoxContainer/ButtonRow/SkipButton
@onready var back_button: Button = $GamePanel/VBoxContainer/ButtonRow/BackButton

const TILE_SCENE := preload("res://scene/Tile.tscn")

## 教程步骤
const STEPS := [
	{"title": "欢迎来到联机对战！", "text": "你将与好友在同一张棋盘上同时消除，先清空棋盘者获胜！"},
	{"title": "创建或加入房间", "text": "点击「创建房间」成为房主，或点击「加入房间」输入好友 IP 地址连接。"},
	{"title": "共享棋盘", "text": "你们看到的是同一张牌桌！你消掉的牌，对手就消不了——这就是「抢牌」的乐趣。"},
	{"title": "选牌消除（和单机一样）", "text": "点击两张相同牌即可消除。但注意：如果对手先点了那张牌，你就选不到了！"},
	{"title": "攻击技能", "text": "每次成功消除获得 1 点能量。能量足够时可以释放攻击：\n🌫 迷雾（2能量）— 对手牌面模糊 3 秒\n🌀 乱风（3能量）— 随机推移对手 3 张牌\n❄️ 冰冻（4能量）— 对手 2 秒无法点击\n🔥 烈焰（5能量）— 给对手棋盘加 2 张新牌"},
	{"title": "胜负判定", "text": "先清空自己这边的棋盘者获胜！\n如果 15 秒没有任何操作，会被判负（防挂机）。"},
	{"title": "三局两胜", "text": "对战采用三局两胜制。每局结束后会进入下一局，先赢 2 局者获得最终胜利！"},
	{"title": "教程结束！", "text": "现在去创建或加入房间，和朋友一较高下吧！点击「开始对战」进入大厅。"},
]

## 演示棋盘参数（小型演示用）
const DEMO_STEP_X := 30
const DEMO_STEP_Y := 40
const DEMO_Z_OFFSET_X := 6
const DEMO_Z_OFFSET_Y := 10
const DEMO_TILE_SIZE := Vector2(56, 82)
const DEMO_PADDING := Vector2(18, 14)
const DEMO_MAX_SCALE := 2.0

var _step := 0
var _demo_tiles: Dictionary = {}
var _tile_nodes: Dictionary = {}


func _ready() -> void:
	_apply_whatajong_ui()
	board_container.resized.connect(_on_board_container_resized)
	_show_step()
	_maybe_build_demo_board()


func _on_next_button_pressed() -> void:
	_step += 1
	if _step >= STEPS.size():
		_on_skip_button_pressed()  # 教程结束
		return
	_show_step()
	_maybe_build_demo_board()


func _on_skip_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/pvp_lobby.tscn")


func _show_step() -> void:
	var step: Dictionary = STEPS[_step]
	title_label.text = step["title"]
	status_label.text = step["text"]
	next_button.text = "下一步" if _step < STEPS.size() - 1 else "开始对战"
	skip_button.visible = _step > 0
	var show_demo := (_step == 3 or _step == 4)
	board_container.visible = show_demo
	board_container.custom_minimum_size = Vector2(0, 210) if show_demo else Vector2.ZERO


func _maybe_build_demo_board() -> void:
	# 在第 3、4 步时展示一个小型演示棋盘
	if _step == 3 or _step == 4:
		_build_demo_board()
	else:
		_clear_demo_board()


func _build_demo_board() -> void:
	_clear_demo_board()
	var rng := RandomNumberGenerator.new()
	rng.set_seed(42)
	var mini_deck: Array[Dictionary] = [
		{"cardId": "bam1", "material": "bone"},
		{"cardId": "bam1", "material": "bone"},
		{"cardId": "crack2", "material": "bone"},
		{"cardId": "crack2", "material": "bone"},
		{"cardId": "dot3", "material": "bone"},
		{"cardId": "dot3", "material": "bone"},
	]
	_demo_tiles = SetupTiles.setup_tiles(rng, mini_deck)
	for tile in _sorted_tiles(_demo_tiles):
		var tile_id := String(tile["id"])
		var card_id := String(tile["card_id"])
		var node := TILE_SCENE.instantiate() as Tile
		tile_layer.add_child(node)
		node.setup(tile_id, card_id, _get_icon(card_id), "bone")
		node.z_index = int(tile["z"]) * 100 + int(tile["x"]) + int(tile["y"]) * 2
		node.tile_clicked.connect(_on_demo_tile_pressed.bind(tile_id))
		_tile_nodes[tile_id] = node
	_refresh_demo_tiles()
	_layout_demo_tiles()


func _clear_demo_board() -> void:
	for child in tile_layer.get_children():
		child.queue_free()
	_tile_nodes.clear()
	_demo_tiles.clear()


func _on_demo_tile_pressed(tile_id: String) -> void:
	if not _demo_tiles.has(tile_id):
		return
	# 演示：点两张相同的就消除
	var tile: Dictionary = _demo_tiles[tile_id]
	if not tile.get("selected", false):
		tile["selected"] = true
		_demo_tiles[tile_id] = tile
	else:
		tile["deleted"] = true
		_demo_tiles[tile_id] = tile
	_refresh_demo_tiles()


func _refresh_demo_tiles() -> void:
	for tid in _tile_nodes:
		var node: Tile = _tile_nodes[tid]
		var t: Dictionary = _demo_tiles[tid]
		node.set_selected(t.get("selected", false))
		if t.get("deleted", false):
			node.visible = false
		else:
			node.visible = true


func _get_icon(card_id: String) -> Texture2D:
	var path := "res://tiles/%s.webp" % card_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _demo_to_layout_position(tile: Dictionary) -> Vector2:
	return Vector2(
		float(tile["x"]) * DEMO_STEP_X - float(tile["z"]) * DEMO_Z_OFFSET_X,
		float(tile["y"]) * DEMO_STEP_Y - float(tile["z"]) * DEMO_Z_OFFSET_Y
	)


func _get_demo_bounds() -> Rect2:
	var has := false
	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO
	for tile in _demo_tiles.values():
		var t: Dictionary = tile
		var pos := _demo_to_layout_position(t)
		if not has:
			min_pos = pos
			max_pos = pos + DEMO_TILE_SIZE
			has = true
			continue
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x + DEMO_TILE_SIZE.x)
		max_pos.y = maxf(max_pos.y, pos.y + DEMO_TILE_SIZE.y)
	return Rect2(min_pos, max_pos - min_pos) if has else Rect2(Vector2.ZERO, DEMO_TILE_SIZE)


func _get_demo_scale() -> float:
	if _demo_tiles.is_empty():
		return 1.0
	var bounds := _get_demo_bounds()
	var available := board_container.size - DEMO_PADDING * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		return 1.0
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 1.0
	return min(DEMO_MAX_SCALE, min(available.x / bounds.size.x, available.y / bounds.size.y))


func _layout_demo_tiles() -> void:
	if _demo_tiles.is_empty() or _tile_nodes.is_empty():
		return
	var bounds := _get_demo_bounds()
	var scale := _get_demo_scale()
	var available := board_container.size - DEMO_PADDING * 2.0
	var origin := DEMO_PADDING + (available - bounds.size * scale) * 0.5 - bounds.position * scale
	for tid in _tile_nodes.keys():
		if not _demo_tiles.has(tid):
			continue
		var node: Tile = _tile_nodes[tid]
		var tile: Dictionary = _demo_tiles[tid]
		node.position = _demo_to_layout_position(tile) * scale + origin


func _sorted_tiles(db: Dictionary) -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for v in db.values():
		arr.append(v as Dictionary)
	arr.sort_custom(func(a, b):
		if int(a["z"]) != int(b["z"]): return int(a["z"]) < int(b["z"])
		return int(a["y"]) < int(b["y"])
	)
	return arr


func _on_board_container_resized() -> void:
	_layout_demo_tiles()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/pvp_lobby.tscn")


func _apply_whatajong_ui() -> void:
	## 应用 WhatajongUI 样式到所有控件
	WhatajongUI.apply_panel(game_panel, WhatajongUI.COLOR_DOT, Color(0.97, 0.94, 0.86, 0.88), 26, 20)
	WhatajongUI.apply_display_font(title_label, 38)
	WhatajongUI.apply_display_font(status_label, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.apply_display_font(next_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(skip_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(back_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_button(next_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.apply_button(skip_button, WhatajongUI.COLOR_CRACK, 0.88)
	WhatajongUI.apply_button(back_button, WhatajongUI.COLOR_DOT, 0.85)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
