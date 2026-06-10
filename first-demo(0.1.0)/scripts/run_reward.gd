extends Control

@onready var reward_panel: Panel = $RewardPanel
@onready var title_label: Label = $RewardPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $RewardPanel/VBoxContainer/SubtitleLabel
@onready var rewards_container: HBoxContainer = $RewardPanel/VBoxContainer/RewardsContainer
@onready var continue_button: Button = $RewardPanel/VBoxContainer/ContinueButton
@onready var status_label: Label = $RewardPanel/VBoxContainer/StatusLabel

var _reward_items: Array = []


func _ready() -> void:
	_apply_ui()
	_build_rewards()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(reward_panel, WhatajongUI.COLOR_DOT, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_display_font(title_label)
	WhatajongUI.apply_display_font(continue_button)
	WhatajongUI.apply_button(continue_button, WhatajongUI.COLOR_DOT, 0.92)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_body_text(subtitle_label)
	WhatajongUI.tint_body_text(status_label)


func _build_rewards() -> void:
	for child in rewards_container.get_children():
		child.queue_free()

	var level := _get_current_level()
	if level.is_empty():
		status_label.text = "没有可用奖励。"
		continue_button.disabled = true
		return

	var tile_items: Array = level.get("tileItems", [])
	var unique_items := _unique_by_card_id(tile_items)
	var rng := RunState.create_rng("%s-%d" % [
		String(RunManager.run.get("runId", "")),
		int(RunManager.run.get("round", 1)),
	])
	var shuffled := RunState.shuffle_array(unique_items, rng)
	var rewards := int(level.get("rewards", 0))
	_reward_items = []
	for i in range(min(rewards, shuffled.size())):
		_reward_items.append(shuffled[i])

	if _reward_items.is_empty():
		status_label.text = "没有可用奖励。"
		continue_button.disabled = true
		return

	status_label.text = "奖励已获得！点击继续进入商店。"

	for item in _reward_items:
		var card_id := String(item.get("cardId", ""))

		# 外层面板：带圆角和边框的奖励卡
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.tooltip_text = card_id
		WhatajongUI.apply_panel(panel, WhatajongUI.COLOR_DOT, Color(1, 0.97, 0.88, 0.92), 16, 12)

		# 阴影：让奖励牌有浮起感
		var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.shadow_size = 4
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_offset = Vector2(3, 3)

		panel.custom_minimum_size = Vector2(100, 130)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# 牌面图：居中显示，保持宽高比
		var tex := TextureRect.new()
		var texture_path := "res://tiles/%s.webp" % card_id
		if ResourceLoader.exists(texture_path):
			tex.texture = load(texture_path)
		else:
			push_warning("run_reward: 找不到牌面图片 %s" % texture_path)

		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.anchor_left = 0.0
		tex.anchor_top = 0.0
		tex.anchor_right = 1.0
		tex.anchor_bottom = 1.0
		tex.offset_left = 10
		tex.offset_top = 10
		tex.offset_right = -10
		tex.offset_bottom = -10
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE

		panel.add_child(tex)
		rewards_container.add_child(panel)


func _get_current_level() -> Dictionary:
	var round_id := int(RunManager.run.get("round", 1))
	for level in RunManager.get_levels():
		if int(level.get("level", -1)) == round_id:
			return level
	return {}


func _unique_by_card_id(items: Array) -> Array:
	var seen := {}
	var result: Array = []
	for item in items:
		var card_id := String(item.get("cardId", ""))
		if seen.has(card_id):
			continue
		seen[card_id] = true
		result.append(item)
	return result


func _on_continue_button_pressed() -> void:
	RunManager.apply_reward_items(_reward_items)
	RunManager.enter_stage(RunManager.STAGE_SHOP)
