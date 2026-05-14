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
const MATERIAL_COLORS := {
	"bone": Color(0.78, 0.72, 0.62),
	"topaz": Color(0.92, 0.76, 0.30),
	"sapphire": Color(0.25, 0.48, 0.86),
	"garnet": Color(0.72, 0.24, 0.28),
	"ruby": Color(0.94, 0.18, 0.25),
	"jade": Color(0.36, 0.68, 0.42),
	"emerald": Color(0.08, 0.72, 0.45),
	"quartz": Color(0.78, 0.80, 0.86),
	"obsidian": Color(0.18, 0.20, 0.25),
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
@onready var detail_tab_button: Button = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/TabRow/DetailTabButton
@onready var deck_tab_button: Button = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/TabRow/DeckTabButton
@onready var detail_title_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailTitleLabel
@onready var detail_icon: TextureRect = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailIcon
@onready var detail_cost_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailCostLabel
@onready var detail_stats_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailStatsLabel
@onready var detail_deck_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailDeckLabel
@onready var detail_upgrade_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailUpgradeLabel
@onready var detail_hint_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DetailHintLabel
@onready var deck_summary_label: Label = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DeckSummaryLabel
@onready var deck_scroll: ScrollContainer = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DeckScroll
@onready var deck_list_container: VBoxContainer = $ShopPanel/VBoxContainer/ContentRow/DetailPanel/DetailMargin/DetailVBox/DeckScroll/DeckListContainer
@onready var reroll_button: Button = $ShopPanel/VBoxContainer/ActionRow/RerollButton
@onready var freeze_button: Button = $ShopPanel/VBoxContainer/ActionRow/FreezeButton
@onready var continue_button: Button = $ShopPanel/VBoxContainer/ActionRow/ContinueButton
@onready var status_label: Label = $ShopPanel/VBoxContainer/StatusLabel

var _current_items: Array = []
var _item_buttons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _selected_item_id := ""
var _active_tab := "detail"
var _last_changed_card_id := ""
var _deck_tab_tween: Tween


func _ready() -> void:
	detail_tab_button.pressed.connect(_on_detail_tab_pressed)
	deck_tab_button.pressed.connect(_on_deck_tab_pressed)
	_apply_ui()
	_refresh_items()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(shop_panel, WhatajongUI.COLOR_CRACK, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_panel(detail_panel, WhatajongUI.COLOR_DOT, Color(0.98, 0.96, 0.90, 0.72), 22, 12)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(reroll_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(freeze_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(continue_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(detail_tab_button, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(deck_tab_button, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(detail_title_label, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_button(reroll_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.apply_button(freeze_button, WhatajongUI.COLOR_DOT, 0.92)
	WhatajongUI.apply_button(continue_button, WhatajongUI.COLOR_CRACK, 0.92)
	WhatajongUI.apply_button(detail_tab_button, WhatajongUI.COLOR_DOT, 0.90, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_button(deck_tab_button, WhatajongUI.COLOR_BAM, 0.90, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_label(detail_title_label, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_body_text(money_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(deck_summary_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_cost_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(detail_stats_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_deck_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_upgrade_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(detail_hint_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	_set_active_tab("detail")


func _refresh_items() -> void:
	_current_items = RunManager.get_items()
	_item_buttons.clear()
	_update_money_label()
	_update_freeze_label()
	_refresh_deck_view()

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
	_refresh_deck_view()
	if update_status:
		status_label.text = "已选择：%s" % _get_card_display_name(String(item.get("cardId", "")))


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

	detail_title_label.text = _get_card_display_name(card_id)
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
		detail_upgrade_label.text = "购买效果：加入 1 张%s牌。" % _get_material_name("bone")
		detail_hint_label.text = "买入后进入当前牌组，并从下一局开始参与发牌。"
	else:
		var lines: Array[String] = []
		for path in upgrade_paths:
			var next_material := RunState.get_next_material(deck_tiles, path)
			lines.append("%s路线 -> %s" % [_get_path_name(path), _get_material_name(next_material)])
		detail_upgrade_label.text = "升级预览：\n%s" % "\n".join(lines)
		detail_hint_label.text = "升级后会更新当前牌组，并从下一局开始生效。"


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


func _on_detail_tab_pressed() -> void:
	_set_active_tab("detail")


func _on_deck_tab_pressed() -> void:
	_set_active_tab("deck")


func _set_active_tab(tab: String) -> void:
	_active_tab = tab
	var show_detail := tab == "detail"

	detail_tab_button.button_pressed = show_detail
	deck_tab_button.button_pressed = not show_detail

	for control in [
		detail_title_label,
		detail_icon,
		detail_cost_label,
		detail_stats_label,
		detail_deck_label,
		detail_upgrade_label,
		detail_hint_label,
	]:
		(control as CanvasItem).visible = show_detail

	deck_summary_label.visible = not show_detail
	deck_scroll.visible = not show_detail
	if not show_detail:
		_refresh_deck_view()


func _flash_deck_tab() -> void:
	if _deck_tab_tween != null and _deck_tab_tween.is_valid():
		_deck_tab_tween.kill()

	deck_tab_button.modulate = Color(1.18, 1.12, 0.82, 1.0)
	_deck_tab_tween = create_tween()
	_deck_tab_tween.tween_property(deck_tab_button, "modulate", Color.WHITE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _refresh_deck_view() -> void:
	if deck_list_container == null:
		return

	for child in deck_list_container.get_children():
		child.queue_free()

	var entries := _build_deck_entries()
	deck_summary_label.text = _build_deck_summary(entries)

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前牌组为空。"
		WhatajongUI.tint_body_text(empty_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
		deck_list_container.add_child(empty_label)
		return

	var current_section := ""
	for entry in entries:
		var section := _get_deck_section(entry)
		if section != current_section:
			current_section = section
			deck_list_container.add_child(_build_deck_section_label(section))
		deck_list_container.add_child(_build_deck_row(entry))


func _build_deck_entries() -> Array[Dictionary]:
	var groups := {}
	for deck_tile in RunManager.deck:
		var card_id := String(deck_tile.get("cardId", ""))
		if card_id == "":
			continue
		if not groups.has(card_id):
			var card := CardData.get_card_by_id(card_id)
			groups[card_id] = {
				"card_id": card_id,
				"card": card,
				"count": 0,
				"materials": {},
			}
		var entry: Dictionary = groups[card_id]
		entry["count"] = int(entry.get("count", 0)) + 1
		var materials: Dictionary = entry["materials"]
		var material := String(deck_tile.get("material", "bone"))
		materials[material] = int(materials.get(material, 0)) + 1
		entry["materials"] = materials
		groups[card_id] = entry

	var entries: Array[Dictionary] = []
	for card_id in groups.keys():
		entries.append(groups[card_id])

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_card: Dictionary = a.get("card", {})
		var b_card: Dictionary = b.get("card", {})
		var a_suit := String(a_card.get("suit", ""))
		var b_suit := String(b_card.get("suit", ""))
		var a_group := 0 if _is_basic_suit(a_suit) else 1
		var b_group := 0 if _is_basic_suit(b_suit) else 1
		if a_group != b_group:
			return a_group < b_group
		if a_suit != b_suit:
			return a_suit < b_suit
		return String(a.get("card_id", "")) < String(b.get("card_id", ""))
	)
	return entries


func _build_deck_summary(entries: Array[Dictionary]) -> String:
	var pair_count := RunManager.deck.size()
	var basic_count := 0
	var special_count := 0
	var advanced_count := 0

	for deck_tile in RunManager.deck:
		var card := CardData.get_card_by_id(String(deck_tile.get("cardId", "")))
		var suit := String(card.get("suit", ""))
		if _is_basic_suit(suit):
			basic_count += 1
		else:
			special_count += 1
		if String(deck_tile.get("material", "bone")) != "bone":
			advanced_count += 1

	return "当前牌组：%d 对 / 下局 %d 张\n普通牌 %d · 特殊牌 %d · 高级材质 %d · 类型 %d" % [
		pair_count,
		pair_count * 2,
		basic_count,
		special_count,
		advanced_count,
		entries.size(),
	]


func _build_deck_section_label(section: String) -> Label:
	var label := Label.new()
	label.text = section
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	WhatajongUI.tint_body_text(label, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_BODY)
	return label


func _build_deck_row(entry: Dictionary) -> Control:
	var card_id := String(entry.get("card_id", ""))
	var card: Dictionary = entry.get("card", {})
	var count := int(entry.get("count", 0))
	var materials: Dictionary = entry.get("materials", {})
	var is_selected := _is_selected_card(card_id)
	var is_changed := card_id == _last_changed_card_id
	var accent := _accent_for_card(card_id)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 112)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 0.86, 0.70).lerp(accent, 0.10 if not is_changed else 0.20)
	style.border_color = accent.lightened(0.12 if is_selected or is_changed else 0.34)
	style.set_border_width_all(3 if is_selected or is_changed else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 72)
	icon.texture = _get_item_icon(card_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	var title := Label.new()
	title.text = "%s  x%d" % [_get_card_display_name(card_id), count]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	WhatajongUI.tint_body_text(title, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_SMALL)
	text_box.add_child(title)

	var material_row := _build_material_row(materials)
	text_box.add_child(material_row)

	var effect := Label.new()
	effect.text = _get_effect_summary(card_id, card)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	WhatajongUI.tint_body_text(effect, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	text_box.add_child(effect)

	return panel


func _build_material_row(materials: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	for material_entry in CardData.MATERIALS:
		var material := String(material_entry)
		var amount := int(materials.get(material, 0))
		if amount <= 0:
			continue

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = MATERIAL_COLORS.get(material, Color.WHITE)
		row.add_child(swatch)

		var label := Label.new()
		label.text = "%s x%d" % [_get_material_name(material), amount]
		WhatajongUI.tint_body_text(label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
		row.add_child(label)

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


func _is_basic_suit(suit: String) -> bool:
	return suit == "bam" or suit == "crack" or suit == "dot"


func _get_deck_section(entry: Dictionary) -> String:
	var card: Dictionary = entry.get("card", {})
	var suit := String(card.get("suit", ""))
	if _is_basic_suit(suit):
		return "基础牌"
	return "特殊牌"


func _is_selected_card(card_id: String) -> bool:
	for item in _current_items:
		var entry: Dictionary = item
		if String(entry.get("id", "")) == _selected_item_id:
			return String(entry.get("cardId", "")) == card_id
	return false


func _get_card_display_name(card_id: String) -> String:
	var card := CardData.get_card_by_id(card_id)
	if card.is_empty():
		return card_id

	var suit := String(card.get("suit", ""))
	var rank := String(card.get("rank", ""))
	match suit:
		"bam", "crack", "dot":
			return "%s %s" % [_get_suit_name(suit), rank]
		"wind":
			return "%s风" % _get_wind_name(rank)
		"dragon":
			return "%s龙" % _get_symbol_name(rank)
		"rabbit":
			return "%s兔" % _get_symbol_name(rank)
		"frog":
			return "%s蛙" % _get_symbol_name(rank)
		"lotus":
			return "%s莲" % _get_symbol_name(rank)
		"sparrow":
			return "%s雀" % _get_symbol_name(rank)
		"shadow":
			return "%s影" % _get_symbol_name(rank)
		"element":
			return "%s元素" % _get_symbol_name(rank)
		"gem":
			return "%s宝石" % _get_symbol_name(rank)
		"phoenix":
			return "凤凰"
		"joker":
			return "万能牌"
		"flower":
			return "花牌 %s" % card_id.replace("flower", "")
		"mutation":
			return "异变 %s" % card_id.replace("mutation", "")
		"taijitu":
			return "%s太极" % _get_symbol_name(rank)
		_:
			return card_id


func _get_effect_summary(card_id: String, card: Dictionary) -> String:
	var suit := String(card.get("suit", ""))
	match suit:
		"bam", "crack", "dot":
			return "基础得分牌，扩充下局牌池。"
		"wind":
			return "消除后向%s推动上层牌。" % _get_wind_direction_text(String(card.get("rank", "")))
		"dragon":
			return "同色龙连续消除会提高得分倍率。"
		"rabbit":
			return "消除时每张兔牌额外获得 1 金币。"
		"frog":
			return "可与同色莲牌配对。"
		"lotus":
			return "可与同色蛙牌配对。"
		"sparrow":
			return "当前版本主要作为同色特殊牌。"
		"shadow":
			return "高基础分特殊牌。"
		"phoenix":
			return "启动凤凰连段，按数字顺序提高倍率。"
		"taijitu":
			return "高基础分特殊牌。"
		"mutation":
			return "消除前会交换棋盘上的基础花色。"
		"flower":
			return "任意两张花牌可以互相配对。"
		"element":
			return "中高基础分特殊牌。"
		"gem":
			return "消除后为后续得分设置临时材质。"
		"joker":
			return "消除后尝试重洗剩余牌面。"
		_:
			return card_id


func _get_symbol_name(symbol: String) -> String:
	match symbol:
		"r":
			return "红"
		"g":
			return "绿"
		"b":
			return "蓝"
		"k":
			return "黑"
		_:
			return symbol


func _get_wind_name(rank: String) -> String:
	match rank:
		"n":
			return "北"
		"s":
			return "南"
		"e":
			return "东"
		"w":
			return "西"
		_:
			return rank


func _get_wind_direction_text(rank: String) -> String:
	match rank:
		"n":
			return "上方"
		"s":
			return "下方"
		"e":
			return "右侧"
		"w":
			return "左侧"
		_:
			return "对应方向"


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
	var card_id := String(item.get("cardId", ""))
	if RunState.buy_tile(RunManager.run, item, RunManager.deck):
		_last_changed_card_id = card_id
		_refresh_items()
		status_label.text = "已加入牌组：%s · 下局生效" % _get_card_display_name(card_id)
		_flash_deck_tab()
	else:
		status_label.text = "金币不足，无法购买。"


func _on_upgrade_pressed(item: Dictionary, path: String) -> void:
	_select_item(item, false)
	var card_id := String(item.get("cardId", ""))
	var deck_tiles := _get_deck_tiles_by_card_id(card_id)
	var next_material := RunState.get_next_material(deck_tiles, path)
	if RunState.upgrade_tile(RunManager.run, item, RunManager.deck, path):
		_last_changed_card_id = card_id
		_refresh_items()
		status_label.text = "已升级：%s -> %s · 下局生效" % [
			_get_card_display_name(card_id),
			_get_material_name(next_material),
		]
		_flash_deck_tab()
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

	_refresh_items()


func _on_continue_button_pressed() -> void:
	RunManager.advance_to_next_round()
	RunManager.enter_stage(RunManager.STAGE_GAME)
