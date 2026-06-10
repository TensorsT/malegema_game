class_name InventoryPopup
extends RefCounted

const TILE_SCENE := preload("res://scene/Tile.tscn")

# ── 材质颜色（与 run_shop.gd 保持一致） ──
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

const MATERIAL_NAMES := {
	"bone": "骨",
	"topaz": "黄玉",
	"sapphire": "蓝宝石",
	"garnet": "石榴石",
	"ruby": "红宝石",
	"jade": "玉",
	"emerald": "翡翠",
	"quartz": "石英",
	"obsidian": "黑曜石",
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

var _canvas: CanvasLayer
var _panel: Panel
var _summary: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _detail_panel: Panel
var _detail_title: Label
var _detail_tile: Tile
var _detail_info: Label
var _open_tween: Tween
var _close_tween: Tween


func create(parent: Node) -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	parent.add_child(_canvas)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.04, 0.60)
	dim.visible = false
	dim.name = "DimOverlay"
	_canvas.add_child(dim)

	_panel = Panel.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(1320, 1020)
	_panel.position = -_panel.size * 0.5
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = _panel.size * 0.5
	_canvas.add_child(_panel)

	WhatajongUI.apply_panel(_panel, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.98), 24, 20)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "背包"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WhatajongUI.apply_display_font(title)
	WhatajongUI.tint_label(title, WhatajongUI.COLOR_BAM.darkened(0.35))
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	_summary = Label.new()
	_summary.text = ""
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WhatajongUI.apply_display_font(_summary)
	_summary.add_theme_font_size_override("font_size", 14)
	WhatajongUI.tint_body_text(_summary, Color(0.26, 0.20, 0.14, 0.85))
	vbox.add_child(_summary)

	# ── 内容区：左边网格 + 右边详情 ──
	var content_row := HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	vbox.add_child(content_row)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_stretch_ratio = 3.0
	content_row.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_scroll.add_child(_grid)

	# ── 右侧详情面板 ──
	_detail_panel = Panel.new()
	_detail_panel.custom_minimum_size = Vector2(280, 0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.visible = false
	_setup_detail_panel()
	content_row.add_child(_detail_panel)

	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(140, 40)
	WhatajongUI.apply_button(close, WhatajongUI.COLOR_DOT, 0.88)
	close.pressed.connect(_animate_hide)
	vbox.add_child(close)


func _setup_detail_panel() -> void:
	WhatajongUI.apply_panel(_detail_panel, Color(0.18, 0.16, 0.12), Color(0.92, 0.88, 0.80, 0.96), 14, 12)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_detail_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_detail_title = Label.new()
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WhatajongUI.apply_display_font(_detail_title)
	_detail_title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_detail_title)

	# 牌面缩略图
	_detail_tile = TILE_SCENE.instantiate() as Tile
	_detail_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_tile.set_base_scale(Vector2(1.0, 1.0))
	_detail_tile.set_shadow_enabled(false)
	_detail_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_detail_tile)

	# 详情文字
	_detail_info = Label.new()
	_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WhatajongUI.tint_body_text(_detail_info, Color(0.26, 0.20, 0.14, 0.90), WhatajongUI.FONT_SIZE_SMALL)
	vbox.add_child(_detail_info)


func show_inventory(deck: Array[Dictionary], active_card_ids: Array[String] = []) -> void:
	for child in _grid.get_children():
		child.queue_free()

	var normalized: Array[Dictionary] = []
	for item in deck:
		if not (item is Dictionary):
			continue
		var tile: Dictionary = item as Dictionary
		var cid := String(tile.get("cardId", ""))
		if cid == "":
			cid = String(tile.get("card_id", ""))
		if cid != "":
			tile["cardId"] = cid
		if not tile.has("material"):
			tile["material"] = "bone"
		normalized.append(tile)

	if _summary != null:
		var norm_count := normalized.size()
		var active_count := active_card_ids.size()
		var unique_count := 0
		var seen := {}
		for t in normalized:
			var cid := String(t.get("cardId", ""))
			if not seen.has(cid):
				seen[cid] = true
				unique_count += 1
		_summary.text = "共 %d 张牌（%d 种）· 桌上 %d 张" % [norm_count, unique_count, active_count]

	if normalized.is_empty():
		var empty_label := Label.new()
		empty_label.text = "🎒 背包为空"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		WhatajongUI.apply_display_font(empty_label)
		WhatajongUI.tint_label(empty_label, Color(0.90, 0.35, 0.30))
		_grid.add_child(empty_label)
	else:
		var sorted_tiles := _sort_inventory_tiles(normalized)
		for tile in sorted_tiles:
			var cid := String(tile.get("cardId", ""))
			var is_active := active_card_ids.has(cid)
			_grid.add_child(_build_inventory_tile(tile, is_active))

	_detail_panel.visible = false
	_panel.visible = true
	_animate_show()


func _animate_show() -> void:
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	var dim: ColorRect = _canvas.get_node("DimOverlay")
	dim.visible = true
	dim.modulate = Color(1, 1, 1, 0)
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.92, 0.92)
	_open_tween = _panel.create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(dim, "modulate", Color(1, 1, 1, 1), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_hide() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	var dim: ColorRect = _canvas.get_node("DimOverlay")
	_close_tween = _panel.create_tween()
	_close_tween.set_parallel(true)
	_close_tween.tween_property(dim, "modulate", Color(1, 1, 1, 0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_close_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_close_tween.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_close_tween.finished.connect(func() -> void:
		_panel.visible = false
		dim.visible = false
	)


func _build_inventory_tile(tile_data: Dictionary, is_active: bool) -> Control:
	var cid := String(tile_data.get("cardId", ""))
	var material := String(tile_data.get("material", "bone"))
	var mat_color: Color = MATERIAL_COLORS.get(material, Color(0.78, 0.72, 0.62))

	# ── 外框：带材质色底色的小卡片 ──
	var card := Panel.new()
	card.custom_minimum_size = Vector2(80, 110)
	card.clip_contents = true

	# 底色随材质变化：bone=米色, 高级材质=对应色淡色
	var card_style := StyleBoxFlat.new()
	var bg_tint := Color(0.94, 0.91, 0.84).lerp(mat_color.lightened(0.5), 0.35)
	card_style.bg_color = bg_tint
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_color = mat_color.darkened(0.15)
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	card.add_child(margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(card_vbox)

	# ── 牌面缩略图 ──
	var icon_tex := _get_card_icon(cid)
	var tile := TILE_SCENE.instantiate() as Tile
	var tile_id := String(tile_data.get("id", ""))
	if tile_id == "":
		tile_id = cid
	tile.setup("inv_" + tile_id, cid, icon_tex, material)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.set_base_scale(Vector2(0.62, 0.62))
	tile.set_shadow_enabled(false)
	card_vbox.add_child(tile)

	# ── 材质色带（底部细条，明确标识材质等级） ──
	var mat_band := ColorRect.new()
	mat_band.custom_minimum_size = Vector2(60, 4)
	mat_band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mat_band.color = mat_color
	card_vbox.add_child(mat_band)

	# ── 桌上牌半透明 ──
	if is_active:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.55)
		mat_band.modulate = Color(1.0, 1.0, 1.0, 0.55)

	# ── 悬停显示详情 ──
	card.mouse_entered.connect(_on_tile_hover.bind(tile_data))
	card.mouse_exited.connect(_on_tile_unhover)

	return card


func _on_tile_hover(tile_data: Dictionary) -> void:
	var cid := String(tile_data.get("cardId", ""))
	var material := String(tile_data.get("material", "bone"))
	var card_info := CardData.get_card_by_id(cid)

	# 更新详情面板
	var display_name := _get_card_display_name(cid, card_info)
	_detail_title.text = display_name
	WhatajongUI.tint_label(_detail_title, MATERIAL_COLORS.get(material, Color(0.26, 0.20, 0.14)))

	# 更新详情牌面
	var icon_tex := _get_card_icon(cid)
	_detail_tile.setup("detail_inv", cid, icon_tex, material)
	_detail_tile.set_base_scale(Vector2(1.2, 1.2))

	# 构建详情文字
	var info_lines: Array[String] = []
	info_lines.append("牌型：%s" % cid)

	var suit := String(card_info.get("suit", ""))
	if suit != "":
		info_lines.append("花色：%s" % SUIT_NAMES.get(suit, suit))

	var rank := String(card_info.get("rank", ""))
	if rank != "":
		info_lines.append("数字：%s" % rank)

	var points := int(card_info.get("points", 0))
	info_lines.append("基础分：%d" % points)
	info_lines.append("材质：%s" % MATERIAL_NAMES.get(material, material))

	var colors: Array = card_info.get("colors", [])
	if not colors.is_empty():
		var color_names: Array[String] = []
		for c in colors:
			color_names.append(_color_name(String(c)))
		info_lines.append("颜色：%s" % "、".join(color_names))

	_detail_info.text = "\n".join(info_lines)
	_detail_panel.visible = true


func _on_tile_unhover() -> void:
	_detail_panel.visible = false


func _get_card_display_name(card_id: String, card_info: Dictionary) -> String:
	var suit := String(card_info.get("suit", ""))
	var rank := String(card_info.get("rank", ""))
	var suit_name: String = SUIT_NAMES.get(suit, suit)
	if suit == "dragon":
		return "龙 · %s" % rank
	if suit == "wind":
		return "风 · %s" % rank
	if suit == "flower":
		return "花"
	if suit == "joker":
		return "万能"
	if rank != "":
		return "%s%s" % [rank, suit_name]
	return card_id


func _color_name(symbol: String) -> String:
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


func _sort_inventory_tiles(tiles: Array[Dictionary]) -> Array[Dictionary]:
	var order := _build_card_order_map()
	var material_order := _build_material_order_map()
	var sorted_tiles: Array[Dictionary] = tiles.duplicate(true)
	sorted_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := String(a.get("cardId", ""))
		var b_id := String(b.get("cardId", ""))
		var a_index := int(order.get(a_id, 9999))
		var b_index := int(order.get(b_id, 9999))
		if a_index != b_index:
			return a_index < b_index
		var a_mat := String(a.get("material", "bone"))
		var b_mat := String(b.get("material", "bone"))
		var a_mat_index := int(material_order.get(a_mat, 999))
		var b_mat_index := int(material_order.get(b_mat, 999))
		if a_mat_index != b_mat_index:
			return a_mat_index < b_mat_index
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return sorted_tiles


func _build_card_order_map() -> Dictionary:
	var map: Dictionary = {}
	var cards := CardData.get_all_cards()
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var card_id := String(card.get("cardId", ""))
		if card_id != "":
			map[card_id] = i
	return map


func _build_material_order_map() -> Dictionary:
	var map: Dictionary = {}
	for i in range(CardData.MATERIALS.size()):
		map[String(CardData.MATERIALS[i])] = i
	return map


func _get_card_icon(card_id: String) -> Texture2D:
	var path := "res://tiles/%s.webp" % card_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
