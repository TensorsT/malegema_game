class_name InventoryPopup
extends RefCounted

const TILE_SCENE := preload("res://scene/Tile.tscn")

var _canvas: CanvasLayer
var _panel: Panel
var _summary: Label
var _scroll: ScrollContainer
var _grid: GridContainer
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

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 11
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)

	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(140, 40)
	WhatajongUI.apply_button(close, WhatajongUI.COLOR_DOT, 0.88)
	close.pressed.connect(_animate_hide)
	vbox.add_child(close)


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
	var card := Panel.new()
	card.custom_minimum_size = Vector2(96, 132)
	card.clip_contents = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	card.add_child(margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 1)
	margin.add_child(card_vbox)

	var cid := String(tile_data.get("cardId", ""))
	var icon_tex := _get_card_icon(cid)
	var tile := TILE_SCENE.instantiate() as Tile
	var tile_id := String(tile_data.get("id", ""))
	var material := String(tile_data.get("material", "bone"))
	if tile_id == "":
		tile_id = cid
	tile.setup("inv_" + tile_id, cid, icon_tex, material)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.set_base_scale(Vector2(0.74, 0.74))
	tile.set_shadow_enabled(false)
	card_vbox.add_child(tile)

	if is_active:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.62)

	return card


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


func _get_main_material(tiles: Array) -> String:
	var counts := {}
	for t in tiles:
		var m := String(t.get("material", "bone"))
		counts[m] = int(counts.get(m, 0)) + 1
	var best := "bone"
	var best_count := 0
	for m in counts.keys():
		if int(counts[m]) > best_count:
			best_count = int(counts[m])
			best = m
	return best


func _get_card_icon(card_id: String) -> Texture2D:
	var path := "res://tiles/%s.webp" % card_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
