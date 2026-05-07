extends Control

@onready var shop_panel: Panel = $ShopPanel
@onready var title_label: Label = $ShopPanel/VBoxContainer/TitleLabel
@onready var money_label: Label = $ShopPanel/VBoxContainer/MoneyLabel
@onready var items_container: VBoxContainer = $ShopPanel/VBoxContainer/ItemsContainer
@onready var reroll_button: Button = $ShopPanel/VBoxContainer/ActionRow/RerollButton
@onready var freeze_button: Button = $ShopPanel/VBoxContainer/ActionRow/FreezeButton
@onready var continue_button: Button = $ShopPanel/VBoxContainer/ActionRow/ContinueButton
@onready var status_label: Label = $ShopPanel/VBoxContainer/StatusLabel

var _current_items: Array = []


func _ready() -> void:
	_apply_ui()
	_refresh_items()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(shop_panel, WhatajongUI.COLOR_CRACK, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_display_font(title_label)
	WhatajongUI.apply_display_font(reroll_button)
	WhatajongUI.apply_display_font(freeze_button)
	WhatajongUI.apply_display_font(continue_button)
	WhatajongUI.apply_button(reroll_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.apply_button(freeze_button, WhatajongUI.COLOR_DOT, 0.92)
	WhatajongUI.apply_button(continue_button, WhatajongUI.COLOR_CRACK, 0.92)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_body_text(money_label)
	WhatajongUI.tint_body_text(status_label)


func _refresh_items() -> void:
	_current_items = RunManager.get_items()
	_update_money_label()
	_update_freeze_label()

	for child in items_container.get_children():
		child.queue_free()

	for item in _current_items:
		items_container.add_child(_build_item_row(item))

	if _current_items.is_empty():
		status_label.text = "当前没有可购买的牌。"
	else:
		status_label.text = "购买或升级牌组后继续下一回合。"


func _build_item_row(item: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var card_id := String(item.get("cardId", ""))
	var cost := int(item.get("cost", 0))
	var label := Label.new()
	label.text = "%s  ($%d)" % [card_id, cost]
	WhatajongUI.tint_body_text(label)

	var buy_button := Button.new()
	buy_button.text = "购买"
	WhatajongUI.apply_button(buy_button, WhatajongUI.COLOR_CRACK, 0.92)

	header.add_child(label)
	header.add_child(buy_button)
	row.add_child(header)

	var upgrade_paths := _get_upgrade_paths(card_id)
	if upgrade_paths.is_empty():
		buy_button.pressed.connect(_on_buy_pressed.bind(item))
	else:
		buy_button.disabled = true
		var upgrade_row := HBoxContainer.new()
		upgrade_row.add_theme_constant_override("separation", 8)
		for path in upgrade_paths:
			var upgrade_button := Button.new()
			upgrade_button.text = "升级 (%s)" % path
			WhatajongUI.apply_button(upgrade_button, WhatajongUI.COLOR_DOT, 0.92)
			upgrade_button.pressed.connect(_on_upgrade_pressed.bind(item, path))
			upgrade_row.add_child(upgrade_button)
		row.add_child(upgrade_row)

	return row


func _get_upgrade_paths(card_id: String) -> Array:
	var card := CardData.get_card_by_id(card_id)
	var colors: Array = card.get("colors", [])
	var deck_tiles := _get_deck_tiles_by_card_id(card_id)
	var paths: Array = []
	for color in colors:
		var path := String(color)
		var next_material := RunState.get_next_material(deck_tiles, path)
		if next_material != "bone":
			paths.append(path)
	return paths


func _get_deck_tiles_by_card_id(card_id: String) -> Array:
	var tiles: Array = []
	for deck_tile in RunManager.deck:
		if String(deck_tile.get("cardId", "")) == card_id:
			tiles.append(deck_tile)
	return tiles


func _update_money_label() -> void:
	var money := int(RunManager.run.get("money", 0))
	money_label.text = "当前金币：%d" % money


func _update_freeze_label() -> void:
	var freeze: Dictionary = RunManager.run.get("freeze", {})
	if freeze.is_empty():
		freeze_button.text = "冻结"
		return
	if bool(freeze.get("active", false)):
		freeze_button.text = "取消冻结"
	else:
		freeze_button.text = "冻结"


func _on_buy_pressed(item: Dictionary) -> void:
	if RunState.buy_tile(RunManager.run, item, RunManager.deck):
		_refresh_items()
	else:
		status_label.text = "金币不足，无法购买。"


func _on_upgrade_pressed(item: Dictionary, path: String) -> void:
	if RunState.upgrade_tile(RunManager.run, item, RunManager.deck, path):
		_refresh_items()
	else:
		status_label.text = "金币不足，无法升级。"


func _on_reroll_button_pressed() -> void:
	var cost := RunState.REROLL_COST
	var money := int(RunManager.run.get("money", 0))
	if cost > money:
		status_label.text = "金币不足，无法重抽。"
		return

	var freeze: Dictionary = RunManager.run.get("freeze", {})
	if not freeze.is_empty():
		if not bool(freeze.get("active", false)):
			RunManager.run["freeze"] = {}

	RunManager.run["money"] = money - cost
	RunManager.run["reroll"] = int(RunManager.run.get("reroll", 0)) + 1
	_refresh_items()


func _on_freeze_button_pressed() -> void:
	var freeze: Dictionary = RunManager.run.get("freeze", {})
	if freeze.is_empty():
		RunManager.run["freeze"] = {
			"round": int(RunManager.run.get("round", 1)),
			"reroll": int(RunManager.run.get("reroll", 0)),
			"active": true,
		}
	else:
		freeze["active"] = not bool(freeze.get("active", false))
		RunManager.run["freeze"] = freeze

	_update_freeze_label()


func _on_continue_button_pressed() -> void:
	RunManager.advance_to_next_round()
	RunManager.enter_stage(RunManager.STAGE_GAME)
