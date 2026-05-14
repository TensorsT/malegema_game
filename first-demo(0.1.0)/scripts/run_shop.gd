extends Control

const MATERIAL_NAMES := {
	"bone": "骨牌",
	"topaz": "黄玉",
	"sapphire": "蓝宝石",
	"garnet": "石榴石",
	"ruby": "红宝石",
	"jade": "玉",
	"emerald": "翡翠",
	"quartz": "石英",
	"obsidian": "黑曜石",
}
const PATH_NAMES := {
	"r": "红色",
	"g": "绿色",
	"b": "蓝色",
	"k": "黑色",
}
const SUIT_NAMES := {
	"bam": "竹",
	"crack": "万",
	"dot": "筒",
	"wind": "风",
	"dragon": "龙",
	"rabbit": "兔",
	"frog": "蛙",
	"lotus": "莲",
	"sparrow": "雀",
	"shadow": "影",
	"phoenix": "凤",
	"taijitu": "太极",
	"mutation": "异变",
	"flower": "花",
	"element": "元素",
	"gem": "宝石",
	"joker": "万能",
}

@onready var shop_panel: Panel = $ShopPanel
@onready var title_label: Label = $ShopPanel/VBoxContainer/TitleLabel
@onready var money_label: Label = $ShopPanel/VBoxContainer/MoneyLabel
@onready var items_container: VBoxContainer = $ShopPanel/VBoxContainer/ContentRow/ItemScroll/ItemsContainer
@onready var detail_panel: Panel = $ShopPanel/VBoxContainer/ContentRow/DetailPanel
@onready var detail_title_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailTitleLabel
@onready var detail_icon: TextureRect = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailIcon
@onready var detail_cost_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailCostLabel
@onready var detail_stats_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailStatsLabel
@onready var detail_deck_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailDeckLabel
@onready var detail_upgrade_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailUpgradeLabel
@onready var detail_hint_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailHintLabel
@onready var reroll_button: Button = $ShopPanel/VBoxContainer/ActionRow/RerollButton
@onready var freeze_button: Button = $ShopPanel/VBoxContainer/ActionRow/FreezeButton
@onready var continue_button: Button = $ShopPanel/VBoxContainer/ActionRow/ContinueButton
@onready var status_label: Label = $ShopPanel/VBoxContainer/StatusLabel

var _current_items: Array = []
var _item_buttons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _selected_item_id := ""


func _ready() -> void:
	_apply_ui()
	_refresh_items()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(shop_panel, WhatajongUI.COLOR_CRACK, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_panel(detail_panel, WhatajongUI.COLOR_DOT, Color(0.98, 0.96, 0.90, 0.72), 22, 12)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(reroll_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(freeze_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(continue_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(detail_title_label, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_button(reroll_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.apply_button(freeze_button, WhatajongUI.COLOR_DOT, 0.92)
	WhatajongUI.apply_button(continue_button, WhatajongUI.COLOR_CRACK, 0.92)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_label(detail_title_label, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_body_text(money_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_cost_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(detail_stats_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_deck_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_upgrade_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_hint_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)


func _refresh_items() -> void:
	_current_items = RunManager.get_items()
	_item_buttons.clear()
	_update_money_label()
	_update_freeze_label()

	for child in items_container.get_children():
		child.queue_free()

	for item in _current_items:
		items_container.add_child(_build_item_row(item))

	if _current_items.is_empty():
		_clear_item_detail()
		status_label.text = "当前没有可购买的牌。"
	else:
		_select_item(_get_selected_or_first_item(), false)
		status_label.text = "选择左侧商品查看详情，购买或升级后继续下一回合。"


func _build_item_row(item: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 70)
	row.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var card_id := String(item.get("cardId", ""))
	var item_id := String(item.get("id", ""))
	var cost := int(item.get("cost", 0))
	var select_button := Button.new()
	select_button.text = _format_item_button_text(card_id, cost)
	select_button.toggle_mode = true
	select_button.custom_minimum_size = Vector2(0, 56)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WhatajongUI.apply_button(select_button, _accent_for_card(card_id), 0.92, WhatajongUI.FONT_SIZE_BODY)
	select_button.pressed.connect(_on_item_select_pressed.bind(item))
	_item_buttons[item_id] = select_button

	var buy_button := Button.new()
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(118, 56)
	WhatajongUI.apply_button(buy_button, WhatajongUI.COLOR_CRACK, 0.92, WhatajongUI.FONT_SIZE_BODY)

	header.add_child(select_button)
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
			upgrade_button.text = "升级%s" % _get_path_name(path)
			upgrade_button.custom_minimum_size = Vector2(142, 50)
			WhatajongUI.apply_button(upgrade_button, WhatajongUI.COLOR_DOT, 0.92, WhatajongUI.FONT_SIZE_SMALL)
			upgrade_button.pressed.connect(_on_upgrade_pressed.bind(item, path))
			upgrade_row.add_child(upgrade_button)
		row.add_child(upgrade_row)

	return row


func _on_item_select_pressed(item: Dictionary) -> void:
	_select_item(item)


func _select_item(item: Dictionary, update_status: bool = true) -> void:
	if item.is_empty():
		_clear_item_detail()
		return

	_selected_item_id = String(item.get("id", ""))
	_update_item_button_states()
	_update_item_detail(item)
	if update_status:
		status_label.text = "已选择：%s" % String(item.get("cardId", ""))


func _get_selected_or_first_item() -> Dictionary:
	for item in _current_items:
		var entry: Dictionary = item
		if String(entry.get("id", "")) == _selected_item_id:
			return entry

	if _current_items.is_empty():
		return {}
	return _current_items[0] as Dictionary


func _update_item_button_states() -> void:
	for item_id in _item_buttons.keys():
		var button := _item_buttons[item_id] as Button
		if button == null or not is_instance_valid(button):
			continue
		button.button_pressed = String(item_id) == _selected_item_id


func _update_item_detail(item: Dictionary) -> void:
	var card_id := String(item.get("cardId", ""))
	var card := CardData.get_card_by_id(card_id)
	var deck_tiles := _get_deck_tiles_by_card_id(card_id)
	var cost := int(item.get("cost", 0))
	var suit := String(card.get("suit", ""))
	var rank := String(card.get("rank", ""))
	var points := int(card.get("points", 0))
	var colors: Array = card.get("colors", [])
	var upgrade_paths := _get_upgrade_paths(card_id)
	var rank_text := ""
	if rank != "":
		rank_text = "    序号：%s" % rank

	detail_title_label.text = card_id
	detail_icon.texture = _get_item_icon(card_id)
	detail_icon.tooltip_text = card_id
	detail_cost_label.text = "价格：%d 金币" % cost
	detail_stats_label.text = "类型：%s    点数：%d    颜色：%s%s" % [
		_get_suit_name(suit),
		points,
		_format_colors(colors),
		rank_text,
	]
	detail_deck_label.text = "牌组已有：%d 张\n材质分布：%s" % [
		deck_tiles.size(),
		_format_material_counts(deck_tiles),
	]

	if upgrade_paths.is_empty():
		detail_upgrade_label.text = "购买效果：加入 1 张%s。" % _get_material_name("bone")
		detail_hint_label.text = "当前没有可合成升级，购买会增加牌组数量。"
	else:
		var lines: Array[String] = []
		for path in upgrade_paths:
			var next_material := RunState.get_next_material(deck_tiles, path)
			lines.append("%s路线 -> %s" % [_get_path_name(path), _get_material_name(next_material)])
		detail_upgrade_label.text = "升级预览：\n%s" % "\n".join(lines)
		detail_hint_label.text = "当前已有足够同类牌，升级会消耗金币并按路线合成材质。"


func _clear_item_detail() -> void:
	_selected_item_id = ""
	_update_item_button_states()
	detail_title_label.text = "选择商品"
	detail_icon.texture = null
	detail_icon.tooltip_text = ""
	detail_cost_label.text = "价格：-"
	detail_stats_label.text = ""
	detail_deck_label.text = ""
	detail_upgrade_label.text = ""
	detail_hint_label.text = "点击左侧商品查看详情。"


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


func _format_item_button_text(card_id: String, cost: int) -> String:
	var card := CardData.get_card_by_id(card_id)
	return "%s    $%d    %s" % [
		card_id,
		cost,
		_get_suit_name(String(card.get("suit", ""))),
	]


func _format_colors(colors: Array) -> String:
	if colors.is_empty():
		return "-"

	var names: Array[String] = []
	for color in colors:
		names.append(_get_path_name(String(color)))
	return " / ".join(names)


func _format_material_counts(deck_tiles: Array) -> String:
	if deck_tiles.is_empty():
		return "尚未拥有"

	var counts := {}
	for deck_tile in deck_tiles:
		var material := String(deck_tile.get("material", "bone"))
		counts[material] = int(counts.get(material, 0)) + 1

	var parts: Array[String] = []
	for material in CardData.MATERIALS:
		var material_name := String(material)
		var amount := int(counts.get(material_name, 0))
		if amount > 0:
			parts.append("%s x%d" % [_get_material_name(material_name), amount])

	return "，".join(parts)


func _get_item_icon(card_id: String) -> Texture2D:
	if _icon_cache.has(card_id):
		return _icon_cache[card_id]

	var candidates := [card_id, "%s1" % card_id]
	for candidate in candidates:
		var path := "res://tiles/%s.webp" % candidate
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			_icon_cache[card_id] = texture
			return texture

	_icon_cache[card_id] = null
	return null


func _accent_for_card(card_id: String) -> Color:
	var card := CardData.get_card_by_id(card_id)
	var suit := String(card.get("suit", ""))
	if suit == "flower" or suit == "joker":
		return Color(0.90, 0.66, 0.22)
	if suit == "phoenix":
		return Color(0.88, 0.44, 0.24)
	if suit == "wind":
		return Color(0.44, 0.53, 0.62)

	var colors: Array = card.get("colors", [])
	if colors.is_empty():
		return WhatajongUI.COLOR_BAM
	return _color_from_symbol(String(colors[0]))


func _color_from_symbol(symbol: String) -> Color:
	match symbol:
		"r":
			return Color(0.84, 0.30, 0.28)
		"b":
			return Color(0.28, 0.48, 0.82)
		"k":
			return Color(0.26, 0.31, 0.37)
		_:
			return Color(0.22, 0.65, 0.40)


func _get_material_name(material_name: String) -> String:
	return String(MATERIAL_NAMES.get(material_name, material_name))


func _get_path_name(path: String) -> String:
	return String(PATH_NAMES.get(path, path))


func _get_suit_name(suit: String) -> String:
	return String(SUIT_NAMES.get(suit, suit if suit != "" else "通用"))


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
	_select_item(item, false)
	if RunState.buy_tile(RunManager.run, item, RunManager.deck):
		_refresh_items()
	else:
		status_label.text = "金币不足，无法购买。"


func _on_upgrade_pressed(item: Dictionary, path: String) -> void:
	_select_item(item, false)
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
