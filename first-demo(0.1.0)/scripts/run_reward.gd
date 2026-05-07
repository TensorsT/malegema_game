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

	status_label.text = "已选择奖励牌，点击继续进入商店。"

	for item in _reward_items:
		var label := Label.new()
		label.text = String(item.get("cardId", ""))
		WhatajongUI.tint_body_text(label)
		rewards_container.add_child(label)


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
