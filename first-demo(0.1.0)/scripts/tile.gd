class_name Tile
extends TextureButton

signal tile_clicked(tile_id: String)

const TILE_SIZE := Vector2(64, 96)
const TILE_DEPTH := Vector2(8, 10)
const SHADOW_OFFSET := Vector2(10, 14)
const DRAW_SIZE := Vector2(82, 120)
const FACE_CORNER := 12
const CHASSIS_CORNER := 14

static var _dummy_texture: Texture2D

var tile_id_str: String = ""
var tile_type: String = ""
var tile_material: String = "bone"
var tile_icon: Texture2D

var is_selected: bool = false
var is_clickable: bool = true
var is_removed: bool = false
var hover_active: bool = false
var is_pressing: bool = false

var accent_color := Color(0.22, 0.65, 0.40)
var face_color := Color(0.97, 0.95, 0.90)
var chassis_color := Color(0.85, 0.79, 0.69)
var edge_color := Color(0.45, 0.39, 0.32)

var _state_tween: Tween
var _feedback_tween: Tween

var _lift_amount: float = 0.0:
	set(value):
		_lift_amount = value
		queue_redraw()

var _glow_amount: float = 0.0:
	set(value):
		_glow_amount = value
		queue_redraw()

var _shine_amount: float = 0.0:
	set(value):
		_shine_amount = value
		queue_redraw()

var _warning_amount: float = 0.0:
	set(value):
		_warning_amount = value
		queue_redraw()

var _flash_amount: float = 0.0:
	set(value):
		_flash_amount = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = DRAW_SIZE
	size = DRAW_SIZE
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = Vector2(TILE_SIZE.x * 0.5 + TILE_DEPTH.x * 0.5, TILE_SIZE.y * 0.55)

	var dummy := _get_dummy_texture()
	texture_normal = dummy
	texture_pressed = dummy
	texture_hover = dummy
	texture_disabled = dummy

	pressed.connect(_on_pressed)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_update_visual_state()


func setup(id: String, type: String, icon_texture: Texture2D = null, material_name: String = "bone") -> void:
	tile_id_str = id
	tile_type = type
	tile_material = material_name
	tile_icon = icon_texture

	_apply_palette()
	tooltip_text = _build_tooltip()
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	_update_visual_state()


func set_clickable(value: bool) -> void:
	is_clickable = value
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if value else CURSOR_ARROW
	_update_visual_state()


func play_remove() -> void:
	if is_removed:
		return

	is_removed = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_tween(_state_tween)
	_kill_tween(_feedback_tween)

	var origin := position
	var pop_rotation := randf_range(-7.0, 7.0)

	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "_flash_amount", 1.0, 0.07)
	_feedback_tween.tween_property(self, "_glow_amount", 1.0, 0.07)
	_feedback_tween.tween_property(self, "scale", Vector2(1.14, 0.90), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "rotation_degrees", pop_rotation, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "_lift_amount", 1.0, 0.07)
	_feedback_tween.chain().set_parallel(true)
	_feedback_tween.tween_property(self, "position", origin + Vector2(randf_range(-8.0, 8.0), -24.0), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(0.28, 0.20), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_feedback_tween.tween_property(self, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_feedback_tween.tween_property(self, "_flash_amount", 0.0, 0.20)
	_feedback_tween.tween_property(self, "_glow_amount", 0.0, 0.20)
	_feedback_tween.finished.connect(queue_free)


func play_invalid_feedback() -> void:
	if is_removed:
		return

	_kill_tween(_feedback_tween)

	var origin := position
	var base_rotation := rotation_degrees

	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "_warning_amount", 1.0, 0.06)
	_feedback_tween.tween_property(self, "scale", Vector2(0.97, 1.04), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.chain()
	_feedback_tween.tween_property(self, "position", origin + Vector2(-8.0, 0.0), 0.03)
	_feedback_tween.parallel().tween_property(self, "rotation_degrees", base_rotation - 2.3, 0.03)
	_feedback_tween.tween_property(self, "position", origin + Vector2(8.0, 0.0), 0.03)
	_feedback_tween.parallel().tween_property(self, "rotation_degrees", base_rotation + 2.3, 0.03)
	_feedback_tween.tween_property(self, "position", origin + Vector2(-5.0, 0.0), 0.025)
	_feedback_tween.parallel().tween_property(self, "rotation_degrees", base_rotation - 1.2, 0.025)
	_feedback_tween.tween_property(self, "position", origin, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(self, "rotation_degrees", base_rotation, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(self, "_warning_amount", 0.0, 0.16)
	_feedback_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.finished.connect(_restore_visual_state)


func _draw() -> void:
	var face_origin: Vector2 = Vector2(0.0, -lerpf(0.0, 14.0, _lift_amount))
	var face_rect: Rect2 = Rect2(face_origin, TILE_SIZE)
	var chassis_rect: Rect2 = Rect2(face_origin + TILE_DEPTH, TILE_SIZE)
	var shadow_rect: Rect2 = Rect2(chassis_rect.position + SHADOW_OFFSET, TILE_SIZE)

	var ambient_glow: float = 0.08 if is_clickable else 0.0
	var glow_strength: float = clampf(_glow_amount + ambient_glow, 0.0, 1.15)

	var face_tint: Color = face_color
	face_tint = face_tint.lerp(accent_color.lightened(0.82), 0.06 + glow_strength * 0.08)
	if not is_clickable:
		face_tint = face_tint.lerp(Color(0.74, 0.76, 0.79), 0.55)

	var chassis_tint: Color = chassis_color.lerp(accent_color.darkened(0.15), 0.18)
	if not is_clickable:
		chassis_tint = chassis_tint.lerp(Color(0.44, 0.46, 0.49), 0.35)

	var shadow_color: Color = Color(0.02, 0.03, 0.05, 0.18 + 0.18 * glow_strength)
	if not is_clickable:
		shadow_color = Color(0.02, 0.03, 0.05, 0.12)

	var edge_tint: Color = edge_color.lerp(accent_color.darkened(0.30), 0.30 + glow_strength * 0.15)
	var border_tint: Color = edge_tint
	if is_selected:
		border_tint = border_tint.lerp(accent_color.lightened(0.25), 0.45)

	if glow_strength > 0.01:
		_draw_box(
			face_rect.grow(6.0 + glow_strength * 10.0),
			Color(accent_color.r, accent_color.g, accent_color.b, 0.05 * glow_strength),
			Color(accent_color.r, accent_color.g, accent_color.b, 0.24 * glow_strength),
			18,
			2
		)

	_draw_box(shadow_rect, shadow_color, Color(0, 0, 0, 0), CHASSIS_CORNER, 0)
	_draw_side_polygons(face_rect, chassis_rect, chassis_tint, edge_tint)
	_draw_box(chassis_rect, chassis_tint, edge_tint.darkened(0.12), CHASSIS_CORNER, 2)
	_draw_box(face_rect, face_tint, border_tint, FACE_CORNER, 2)

	var top_band: Rect2 = Rect2(face_rect.position + Vector2(6.0, 6.0), Vector2(face_rect.size.x - 12.0, 6.0))
	draw_rect(top_band, Color(accent_color.r, accent_color.g, accent_color.b, 0.44 + glow_strength * 0.12), true)

	var gloss_polygon: PackedVector2Array = PackedVector2Array([
		face_rect.position + Vector2(8.0, 8.0),
		face_rect.position + Vector2(face_rect.size.x - 12.0, 8.0),
		face_rect.position + Vector2(face_rect.size.x * 0.58, face_rect.size.y * 0.44),
		face_rect.position + Vector2(8.0, face_rect.size.y * 0.30),
	])
	draw_colored_polygon(gloss_polygon, Color(1, 1, 1, 0.08 + _shine_amount * 0.18))

	var inner_shadow: Rect2 = Rect2(face_rect.position + Vector2(8.0, face_rect.size.y * 0.62), Vector2(face_rect.size.x - 16.0, face_rect.size.y * 0.22))
	draw_rect(inner_shadow, Color(0.12, 0.16, 0.20, 0.05), true)

	_draw_icon(face_rect)

	if _warning_amount > 0.01:
		_draw_box(
			face_rect.grow(1.0),
			Color(1.0, 0.38, 0.32, 0.12 * _warning_amount),
			Color(1.0, 0.45, 0.36, 0.28 * _warning_amount),
			FACE_CORNER + 1,
			2
		)

	if _flash_amount > 0.01:
		_draw_box(
			face_rect.grow(2.0),
			Color(1.0, 0.96, 0.78, 0.22 * _flash_amount),
			Color(1.0, 0.87, 0.45, 0.32 * _flash_amount),
			FACE_CORNER + 2,
			2
		)


func _on_pressed() -> void:
	if is_removed:
		return
	tile_clicked.emit(tile_id_str)


func _on_button_down() -> void:
	if is_removed:
		return
	is_pressing = true
	_update_visual_state()


func _on_button_up() -> void:
	is_pressing = false
	_update_visual_state()


func _on_mouse_entered() -> void:
	if is_removed:
		return
	hover_active = true
	_update_visual_state()


func _on_mouse_exited() -> void:
	hover_active = false
	is_pressing = false
	_update_visual_state()


func _update_visual_state() -> void:
	if is_removed:
		return

	_kill_tween(_state_tween)

	var target_lift := 0.0
	if is_selected:
		target_lift = 1.0
	elif hover_active and is_clickable:
		target_lift = 0.45

	var target_glow := 0.0
	if is_selected:
		target_glow = 0.95
	elif hover_active and is_clickable:
		target_glow = 0.40

	var target_shine := 0.28
	if is_selected:
		target_shine = 0.75
	elif hover_active and is_clickable:
		target_shine = 0.55

	var target_scale := Vector2.ONE
	if is_selected:
		target_scale = Vector2(1.08, 1.08)
	elif hover_active and is_clickable:
		target_scale = Vector2(1.03, 1.03)

	if is_pressing and is_clickable:
		target_scale *= Vector2(0.985, 0.94)

	var target_rotation := 0.0
	if is_selected:
		target_rotation = -1.2
	elif hover_active and is_clickable:
		target_rotation = -0.5

	_state_tween = create_tween()
	_state_tween.set_parallel(true)
	_state_tween.tween_property(self, "_lift_amount", target_lift, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(self, "_glow_amount", target_glow, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(self, "_shine_amount", target_shine, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(self, "scale", target_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(self, "rotation_degrees", target_rotation, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _restore_visual_state() -> void:
	if is_removed:
		return
	position = position.round()
	_warning_amount = 0.0
	_update_visual_state()


func _apply_palette() -> void:
	var material_tint := _get_material_tint(tile_material)
	accent_color = _get_card_accent(tile_type)
	face_color = Color(0.975, 0.958, 0.920).lerp(material_tint.lightened(0.80), 0.14)
	chassis_color = Color(0.84, 0.79, 0.70).lerp(material_tint, 0.24)
	edge_color = chassis_color.darkened(0.42)


func _build_tooltip() -> String:
	var card := CardData.get_card_by_id(tile_type)
	if card.is_empty():
		return tile_type

	var colors: Array = card.get("colors", [])
	var color_names: Array[String] = []
	for entry in colors:
		color_names.append(String(entry))

	return "%s\nSuit: %s\nRank: %s\nMaterial: %s\nColors: %s\nPoints: %d" % [
		tile_type,
		String(card.get("suit", "")),
		String(card.get("rank", "")),
		tile_material,
		", ".join(color_names),
		int(card.get("points", 0)),
	]


func _draw_side_polygons(face_rect: Rect2, chassis_rect: Rect2, fill_color: Color, stroke_color: Color) -> void:
	var right_side := PackedVector2Array([
		face_rect.position + Vector2(face_rect.size.x, 0.0),
		chassis_rect.position + Vector2(chassis_rect.size.x, 0.0),
		chassis_rect.position + chassis_rect.size,
		face_rect.position + face_rect.size,
	])
	var bottom_side := PackedVector2Array([
		face_rect.position + Vector2(0.0, face_rect.size.y),
		face_rect.position + face_rect.size,
		chassis_rect.position + chassis_rect.size,
		chassis_rect.position + Vector2(0.0, chassis_rect.size.y),
	])

	draw_colored_polygon(bottom_side, fill_color.darkened(0.05))
	draw_colored_polygon(right_side, fill_color.darkened(0.14))
	draw_polyline(right_side, stroke_color, 2.0, true)
	draw_polyline(bottom_side, stroke_color, 2.0, true)


func _draw_box(rect: Rect2, fill_color: Color, border_color: Color, radius: int, border_width: int) -> void:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill_color
	style_box.corner_radius_top_left = radius
	style_box.corner_radius_top_right = radius
	style_box.corner_radius_bottom_left = radius
	style_box.corner_radius_bottom_right = radius

	if border_width > 0:
		style_box.border_color = border_color
		style_box.border_width_top = border_width
		style_box.border_width_bottom = border_width
		style_box.border_width_left = border_width
		style_box.border_width_right = border_width

	draw_style_box(style_box, rect)


func _draw_icon(face_rect: Rect2) -> void:
	if tile_icon == null:
		return

	var icon_area: Rect2 = Rect2(face_rect.position + Vector2(8.0, 14.0), face_rect.size - Vector2(16.0, 24.0))
	var texture_size: Vector2 = tile_icon.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fill_ratio: float = 0.76 + _glow_amount * 0.04
	var scale_factor: float = minf(icon_area.size.x / texture_size.x, icon_area.size.y / texture_size.y) * fill_ratio
	var draw_size: Vector2 = texture_size * scale_factor
	var icon_draw_rect: Rect2 = Rect2(icon_area.position + (icon_area.size - draw_size) * 0.5, draw_size)

	var icon_modulate := Color(1, 1, 1, 0.96 if is_clickable else 0.60)
	if is_selected:
		icon_modulate = icon_modulate.lerp(Color(accent_color.r, accent_color.g, accent_color.b, icon_modulate.a), 0.16)
	if _warning_amount > 0.01:
		icon_modulate = icon_modulate.lerp(Color(1.0, 0.74, 0.70, icon_modulate.a), 0.20 * _warning_amount)

	draw_texture_rect(tile_icon, icon_draw_rect, false, icon_modulate)
	draw_texture_rect(tile_icon, icon_draw_rect.grow(1.0), false, Color(1, 1, 1, 0.03 + _glow_amount * 0.06))


func _get_card_accent(card_id: String) -> Color:
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
		return Color(0.22, 0.65, 0.40)

	return _color_from_symbol(String(colors[0]))


func _get_material_tint(material_name: String) -> Color:
	match material_name:
		"topaz":
			return Color(0.92, 0.72, 0.26)
		"sapphire":
			return Color(0.31, 0.51, 0.84)
		"garnet":
			return Color(0.70, 0.34, 0.30)
		"ruby":
			return Color(0.85, 0.22, 0.26)
		"jade":
			return Color(0.38, 0.72, 0.60)
		"emerald":
			return Color(0.16, 0.58, 0.36)
		"quartz":
			return Color(0.70, 0.68, 0.80)
		"obsidian":
			return Color(0.20, 0.23, 0.28)
		_:
			return Color(0.84, 0.79, 0.70)


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


func _get_dummy_texture() -> Texture2D:
	if _dummy_texture != null:
		return _dummy_texture

	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	_dummy_texture = ImageTexture.create_from_image(image)
	return _dummy_texture


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
