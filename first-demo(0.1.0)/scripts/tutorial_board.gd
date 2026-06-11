extends "res://scripts/board.gd"
class_name TutorialBoard

const TUTORIAL_SAVE_PATH := "user://tutorial_completed.save"

enum Phase {
	PHASE_1_SIMPLE,
	PHASE_2_BLOCKED,
	PHASE_3_LAYERED,
	COMPLETE,
}

const PHASE_INSTRUCTIONS := {
	Phase.PHASE_1_SIMPLE: "[center][b]第一阶段：简单消除[/b][/center]\n欢迎来到教程！点击两张相同的牌即可消除它们。\n提示：高亮的牌是可点击的。",
	Phase.PHASE_2_BLOCKED: "[center][b]第二阶段：被夹住的牌[/b][/center]\n中间的牌被左右两侧夹住时无法点击。\n先消除边缘的牌，中间的牌就会被释放。",
	Phase.PHASE_3_LAYERED: "[center][b]第三阶段：上层压牌[/b][/center]\n上层的牌会压住下层的牌，使下层无法点击。\n先消除上层，再消除下层。",
	Phase.COMPLETE: "[center][b]教程完成！[/b][/center]\n你已经掌握了基本规则。准备好开始真正的挑战了吗？",
}

const PHASE_NEXT_LABEL := {
	Phase.PHASE_1_SIMPLE: "下一步",
	Phase.PHASE_2_BLOCKED: "下一步",
	Phase.PHASE_3_LAYERED: "完成教程",
	Phase.COMPLETE: "开始游戏",
}

var current_phase: Phase = Phase.PHASE_1_SIMPLE
var tutorial_overlay: Panel
var instruction_label: RichTextLabel
var next_button: Button
var phase_completed: bool = false
var highlighted_tile_ids: Array[String] = []
var _prevent_wrong_click_message: float = 0.0

func _ready() -> void:
	_apply_whatajong_ui()
	_setup_audio()
	_setup_ambient_particles()
	board_container.resized.connect(_on_board_container_resized)
	_on_board_container_resized()
	_init_tutorial_ui()
	_setup_tutorial_phase()
	set_process(true)


func _setup_wind_gust_overlay() -> void:
	wind_gust_overlay = null


func _get_wind_direction_for_tile(_tile: Dictionary) -> Vector2:
	return Vector2.ZERO


func _play_wind_gust(_direction: Vector2) -> void:
	pass


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
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)

	board_shadow.color = Color(0.03, 0.04, 0.05, 0.24)
	board_surface.color = Color(0.20, 0.40, 0.34, 0.94)
	board_inset.color = Color(0.28, 0.50, 0.42, 0.50)
	board_glow.color = Color(0.84, 0.96, 0.86, 0.14)


func _process(delta: float) -> void:
	super._process(delta)
	if _prevent_wrong_click_message > 0.0:
		_prevent_wrong_click_message -= delta


func _setup_new_round() -> void:
	# 教程中不调用父类的随机开局
	pass


func _init_tutorial_ui() -> void:
	tutorial_overlay = Panel.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_overlay.offset_top = -180.0
	tutorial_overlay.offset_bottom = 0.0
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tutorial_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	tutorial_overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	instruction_label = RichTextLabel.new()
	instruction_label.bbcode_enabled = true
	instruction_label.fit_content = true
	instruction_label.scroll_active = false
	instruction_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(instruction_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 16)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_row)

	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(160, 48)
	next_button.pressed.connect(_on_next_button_pressed)
	button_row.add_child(next_button)

	var skip_button := Button.new()
	skip_button.text = "跳过教程"
	skip_button.custom_minimum_size = Vector2(140, 44)
	skip_button.pressed.connect(_on_skip_button_pressed)
	button_row.add_child(skip_button)
	WhatajongUI.apply_button(skip_button, WhatajongUI.COLOR_DOT, 0.75)
	skip_button.add_theme_font_size_override("font_size", 16)

	_StyleTutorialOverlay()


func _StyleTutorialOverlay() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.11, 0.92)
	style.border_color = Color(0.35, 0.55, 0.48, 0.80)
	style.border_width_top = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, -4)
	tutorial_overlay.add_theme_stylebox_override("panel", style)

	WhatajongUI.apply_display_font(instruction_label)
	WhatajongUI.apply_display_font(next_button)
	WhatajongUI.apply_button(next_button, WhatajongUI.COLOR_BAM, 0.92)
	instruction_label.add_theme_color_override("default_color", Color(0.92, 0.90, 0.84, 1.0))
	instruction_label.add_theme_font_size_override("font_size", 20)
	next_button.add_theme_font_size_override("font_size", 18)


func _setup_tutorial_phase() -> void:
	phase_completed = false
	_clear_highlights()
	_clear_tiles()
	board_shadow.visible = true
	board_surface.visible = true
	board_inset.visible = true
	board_glow.visible = true

	match current_phase:
		Phase.PHASE_1_SIMPLE:
			_setup_phase_1()
		Phase.PHASE_2_BLOCKED:
			_setup_phase_2()
		Phase.PHASE_3_LAYERED:
			_setup_phase_3()
		Phase.COMPLETE:
			_setup_complete()

	_refresh_tiles_state()
	_update_instruction_ui()


func _clear_tiles() -> void:
	tile_db.clear()
	tile_nodes.clear()
	for child in tile_layer.get_children():
		child.queue_free()
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


func _add_tile(id: String, card_id: String, x: int, y: int, z: int) -> void:
	tile_db[id] = {
		"id": id,
		"card_id": card_id,
		"material": "bone",
		"x": x,
		"y": y,
		"z": z,
		"deleted": false,
		"selected": false,
	}
	var tile_node := TILE_SCENE.instantiate() as Tile
	tile_layer.add_child(tile_node)
	tile_node.setup(id, card_id, _get_icon(card_id), "bone")
	tile_node.position = _to_screen_position(tile_db[id])
	tile_node.z_index = int(z) * 100 + int(x) + int(y) * 2
	tile_node.tile_clicked.connect(_on_tile_pressed)
	tile_node.tree_exited.connect(_on_tile_node_tree_exited.bind(id, tile_node))
	tile_nodes[id] = tile_node


func _setup_phase_1() -> void:
	status_label.text = "找到两张相同的牌并点击它们"
	title_label.text = "教程：简单消除"
	# 2 pairs, all free, compact layout
	_add_tile("p1_a", "bam1", 4, 4, 0)
	_add_tile("p1_b", "bam1", 6, 4, 0)
	_add_tile("p1_c", "dot1", 4, 6, 0)
	_add_tile("p1_d", "dot1", 6, 6, 0)
	_highlight_tiles(["p1_a", "p1_b"])


func _setup_phase_2() -> void:
	status_label.text = "注意中间被夹住的牌"
	title_label.text = "教程：被夹住的牌"
	# Row: bam1 - dot1(blocked) - bam1, plus free dot1 below
	_add_tile("p2_a", "bam1", 3, 4, 0)
	_add_tile("p2_b", "dot1", 5, 4, 0)
	_add_tile("p2_c", "bam1", 7, 4, 0)
	_add_tile("p2_d", "dot1", 5, 6, 0)
	_highlight_tiles(["p2_a", "p2_c"])


func _setup_phase_3() -> void:
	status_label.text = "上层牌会压住下层牌"
	title_label.text = "教程：上层压牌"
	# One upper tile blocks two lower tiles
	_add_tile("p3_a", "bam1", 4, 4, 0)
	_add_tile("p3_b", "bam1", 6, 4, 0)
	_add_tile("p3_c", "dot1", 5, 4, 1)
	_add_tile("p3_d", "dot1", 5, 6, 1)
	_highlight_tiles(["p3_c", "p3_d"])


func _setup_complete() -> void:
	status_label.text = "教程已完成！"
	title_label.text = "教程完成"
	phase_completed = true
	# Hide board tiles, show completion
	for child in tile_layer.get_children():
		child.queue_free()
	board_shadow.visible = false
	board_surface.visible = false
	board_inset.visible = false
	board_glow.visible = false


func _highlight_tiles(ids: Array[String]) -> void:
	for tid in ids:
		var node := _get_live_tile_node(tid)
		if node != null:
			node.set_highlighted(true)
		highlighted_tile_ids.append(tid)


func _clear_highlights() -> void:
	for tid in highlighted_tile_ids:
		var node := _get_live_tile_node(tid)
		if node != null:
			node.set_highlighted(false)
	highlighted_tile_ids.clear()


func _update_instruction_ui() -> void:
	instruction_label.text = PHASE_INSTRUCTIONS.get(current_phase, "")
	next_button.text = PHASE_NEXT_LABEL.get(current_phase, "下一步")
	next_button.visible = phase_completed


func _on_next_button_pressed() -> void:
	match current_phase:
		Phase.PHASE_1_SIMPLE:
			current_phase = Phase.PHASE_2_BLOCKED
			_setup_tutorial_phase()
		Phase.PHASE_2_BLOCKED:
			current_phase = Phase.PHASE_3_LAYERED
			_setup_tutorial_phase()
		Phase.PHASE_3_LAYERED:
			_save_tutorial_completed()
			current_phase = Phase.COMPLETE
			_setup_tutorial_phase()
		Phase.COMPLETE:
			_save_tutorial_completed()
			_go_to_main_game()


func _on_skip_button_pressed() -> void:
	_save_tutorial_completed()
	_go_to_main_game()

func _go_to_main_game() -> void:
	RunManager.start_new_run()
	RunManager.enter_stage(RunManager.STAGE_GAME)


func _save_tutorial_completed() -> void:
	var file := FileAccess.open(TUTORIAL_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("completed")
		file.close()


static func clear_tutorial_completed() -> void:
	if FileAccess.file_exists(TUTORIAL_SAVE_PATH):
		DirAccess.remove_absolute(TUTORIAL_SAVE_PATH)

static func is_tutorial_completed() -> bool:
	return FileAccess.file_exists(TUTORIAL_SAVE_PATH)


func _on_tile_pressed(tile_id: String) -> void:
	if current_phase == Phase.COMPLETE:
		return

	if not tile_db.has(tile_id):
		return
	var tile: Dictionary = tile_db[tile_id]
	if bool(tile["deleted"]):
		return

	# Tutorial-specific guidance for wrong clicks
	if not TileRules.is_free(tile_db, tile):
		_play_click_sound(0.84, -12.0)
		var blocked_node := _get_live_tile_node(tile_id)
		if blocked_node != null:
			blocked_node.play_invalid_feedback()
		_show_blocked_guidance(tile_id)
		return

	_play_click_sound(1.02, -8.0)
	var first_tile := GameLoop._find_selected_tile(tile_db)
	var result := GameLoop.select_tile(tile_db, game_state, tile_id)
	_refresh_tiles_state()
	_play_result_feedback(result, first_tile, tile_id)
	_status_from_result(result)

	# Check phase completion
	_check_phase_progress()


func _show_blocked_guidance(tile_id: String) -> void:
	if _prevent_wrong_click_message > 0.0:
		return
	_prevent_wrong_click_message = 1.5

	match current_phase:
		Phase.PHASE_2_BLOCKED:
			if tile_id == "p2_b":
				status_label.text = "这张牌被左右夹住了，先点击高亮的边缘牌！"
			else:
				status_label.text = "这张牌当前不可点击：被其他牌挡住了。"
		Phase.PHASE_3_LAYERED:
			if tile_id in ["p3_a", "p3_b"]:
				status_label.text = "下层牌被上层压住了，先消除上层的牌！"
			else:
				status_label.text = "这张牌当前不可点击。"
		_:
			status_label.text = "这张牌当前不可点击。"


func _check_phase_progress() -> void:
	var alive := 0
	for t in tile_db.values():
		if not bool((t as Dictionary).get("deleted", false)):
			alive += 1

	if alive == 0 and not phase_completed:
		phase_completed = true
		_clear_highlights()
		_update_instruction_ui()
		status_label.text = "阶段完成！点击下一步继续。"
		return

	# Update highlights based on phase state
	match current_phase:
		Phase.PHASE_1_SIMPLE:
			if tile_db.has("p1_a") and tile_db["p1_a"].get("deleted", false):
				_clear_highlights()
				_highlight_tiles(["p1_c", "p1_d"])
		Phase.PHASE_2_BLOCKED:
			if tile_db.has("p2_a") and tile_db["p2_a"].get("deleted", false):
				_clear_highlights()
				_highlight_tiles(["p2_b", "p2_d"])
		Phase.PHASE_3_LAYERED:
			if tile_db.has("p3_c") and tile_db["p3_c"].get("deleted", false):
				_clear_highlights()
				_highlight_tiles(["p3_a", "p3_b"])


func _on_restart_button_pressed() -> void:
	_setup_tutorial_phase()

func _on_save_exit_button_pressed() -> void:
	# 教程较短，不单独存档，直接返回主菜单
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")


func _update_score_label() -> void:
	var points := int(game_state.get("points", 0))
	if RunManager.has_active_run():
		var round_data := RunManager.get_round()
		var objective := int(round_data.get("pointObjective", 0))
		var timer_points := float(round_data.get("timerPoints", 0.0))
		var penalty := float(game_state.get("time", 0.0)) * timer_points
		var estimated_total := roundi(points - penalty)
		if score_label != null:
			score_label.text = "已有分数：%d / 过关分数：%d / 预计结算：%d" % [points, objective, estimated_total]
	else:
		if score_label != null:
			score_label.text = "已有分数：%d" % points
