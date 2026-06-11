class_name Tile
extends TextureButton

# Tile: 麻将牌的 2.5D 渲染节点
# 继承 TextureButton 获得点击交互能力，但通过自定义 _draw() 实现伪 3D 立体效果
# 核心技巧：用纯代码绘制阴影、厚度侧面、正面、高光，营造立体感

signal tile_clicked(tile_id: String)

# ── 尺寸常量（单位：像素） ──
const TILE_SIZE := Vector2(64, 96)       # 牌的正面大小
const TILE_DEPTH := Vector2(8, 10)       # 牌的厚度偏移（右下延伸，营造 3D 感）
const SHADOW_OFFSET := Vector2(10, 14)   # 阴影相对于底盘的偏移
const DRAW_SIZE := Vector2(82, 120)      # 整个节点的绘制区域（含阴影和厚度）
const FACE_CORNER := 12                  # 正面圆角半径
const CHASSIS_CORNER := 14               # 底盘圆角半径（略大，视觉上更自然）

static var _dummy_texture: Texture2D     # 占位纹理（透明），用于隐藏默认按钮图片

# ── 牌面数据 ──
var tile_id_str: String = ""             # 牌的唯一 ID（坐标字符串）
var tile_type: String = ""               # 牌型（如 "bam1", "windn"）
var tile_material: String = "bone"       # 材质（影响颜色调色板）
var tile_icon: Texture2D                 # 牌面图标纹理

# ── 状态标记 ──
var is_selected: bool = false            # 是否被选中
var is_clickable: bool = true            # 是否可点击
var is_removed: bool = false             # 是否已被消除
var hover_active: bool = false           # 鼠标是否悬停
var is_pressing: bool = false            # 鼠标是否正在按下
var is_highlighted: bool = false         # 是否高亮（提示可配对）
var show_shadow: bool = true             # 是否显示阴影
var base_scale: Vector2 = Vector2.ONE    # 基础缩放（由 Board 根据布局计算）
var elevation_level: int = 0             # 所在层 z（越高阴影越大，强调悬空感）
var depth_below_top: int = 0             # 距当前最高层的层数（越深整体越暗）

# ── 颜色调色板（会根据牌型和材质动态调整） ──
var accent_color := Color(0.22, 0.65, 0.40)    # 强调色（顶部装饰条、发光边框）
var face_color := Color(0.97, 0.95, 0.90)      # 正面底色
var chassis_color := Color(0.85, 0.79, 0.69)   # 底盘/厚度色
var edge_color := Color(0.45, 0.39, 0.32)      # 边缘/边框色

var _state_tween: Tween      # 状态过渡动画（悬停、选中、高亮）
var _feedback_tween: Tween   # 反馈动画（消除、错误点击）

# ── 绘制强度参数（0.0 ~ 1.0，由 Tween 动画驱动） ──
# 这些变量的 setter 会调用 queue_redraw()，触发 _draw() 重绘
var _lift_amount: float = 0.0:
	set(value):
		_lift_amount = value
		queue_redraw()   # 标记需要重绘，下一帧调用 _draw()

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
	# 设置节点尺寸和交互属性
	custom_minimum_size = DRAW_SIZE
	size = DRAW_SIZE
	ignore_texture_size = true                    # 忽略纹理尺寸，使用自定义大小
	stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	focus_mode = Control.FOCUS_NONE               # 不接受键盘焦点
	mouse_filter = Control.MOUSE_FILTER_STOP      # 拦截鼠标事件
	# 设置旋转中心点：牌面中心偏右下（考虑厚度后的视觉中心）
	pivot_offset = Vector2(TILE_SIZE.x * 0.5 + TILE_DEPTH.x * 0.5, TILE_SIZE.y * 0.55)

	# 用透明纹理覆盖默认按钮图片（我们完全通过 _draw() 自定义绘制）
	var dummy := _get_dummy_texture()
	texture_normal = dummy
	texture_pressed = dummy
	texture_hover = dummy
	texture_disabled = dummy

	# 连接信号
	pressed.connect(_on_pressed)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_update_visual_state()


func setup(id: String, type: String, icon_texture: Texture2D = null, material_name: String = "bone") -> void:
	# 初始化牌的数据，触发调色板和重绘
	tile_id_str = id
	tile_type = type
	tile_material = material_name
	tile_icon = icon_texture

	_apply_palette()
	tooltip_text = _build_tooltip()
	queue_redraw()


func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	_update_visual_state()


func set_clickable(value: bool) -> void:
	if is_clickable == value:
		return
	is_clickable = value
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if value else CURSOR_ARROW
	_update_visual_state()


func set_highlighted(value: bool) -> void:
	if is_highlighted == value:
		return
	is_highlighted = value
	_update_visual_state()


func set_shadow_enabled(value: bool) -> void:
	show_shadow = value
	queue_redraw()


func set_base_scale(value: Vector2) -> void:
	if base_scale.is_equal_approx(value):
		return
	base_scale = value
	_update_visual_state()


func set_elevation(level: int, below_top: int) -> void:
	if elevation_level == level and depth_below_top == below_top:
		return
	elevation_level = level
	depth_below_top = below_top
	queue_redraw()


# ── 消除动画 ──
func play_remove() -> void:
	if is_removed:
		return

	is_removed = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 不再响应鼠标
	_kill_tween(_state_tween)
	_kill_tween(_feedback_tween)

	var origin := position
	var pop_rotation := randf_range(-7.0, 7.0)

	# 第一阶段：闪光+抬起（0.07秒）
	# 第二阶段：飞散+缩小+淡出（0.20秒）
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


# ── 错误点击反馈动画（左右摇晃） ──
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


# ═══════════════════════════════════════════════════════════════
# 核心：_draw() —— 2.5D 立体牌的绘制
# ═══════════════════════════════════════════════════════════════
# 绘制顺序（从下到上，后绘制的覆盖先绘制的）：
# 1. 外发光（选中时）
# 2. 阴影（层越高偏移越大）
# 3. 一体式底座（右/下露出的边带 = 厚度）
# 4. 正面（牌面）
# 5. 顶部装饰条
# 6. 高光（光泽反射）
# 7. 内阴影（底部暗区）
# 8. 图标
# 9. 警告/闪光覆盖层
func _draw() -> void:
	# ── 计算矩形位置 ──
	# _lift_amount 控制牌被"抬起"的高度（0=平放，1=完全抬起）
	var face_origin: Vector2 = Vector2(0.0, -lerpf(0.0, 14.0, _lift_amount))
	var face_rect: Rect2 = Rect2(face_origin, TILE_SIZE)
	# 底座 = 正面与厚度偏移的并集（一体式圆角底座，右/下露出的边带即"厚度"）
	# 一体绘制可避免侧面多边形在圆角处露出的杂线
	var base_rect: Rect2 = Rect2(face_origin, TILE_SIZE + TILE_DEPTH)
	# 阴影：层越高偏移越大，强调"悬空"高度
	var shadow_scale: float = 1.0 + 0.35 * float(elevation_level)
	var shadow_rect: Rect2 = Rect2(base_rect.position + SHADOW_OFFSET * shadow_scale, base_rect.size)

	# ── 计算颜色强度 ──
	# 可点击的牌有微弱的环境发光
	var ambient_glow: float = 0.08 if is_clickable else 0.0
	var glow_strength: float = clampf(_glow_amount + ambient_glow, 0.0, 1.15)
	# 层深阴影：距最高层越远整体越暗，用于区分上下层
	var depth_shade: float = clampf(float(depth_below_top) * 0.05, 0.0, 0.18)

	# ── 根据状态调整颜色 ──
	# 正面：基础色 + 强调色混合（选中/悬停更亮）
	var face_tint: Color = face_color
	face_tint = face_tint.lerp(accent_color.lightened(0.82), 0.06 + glow_strength * 0.08)
	if not is_clickable:
		face_tint = face_tint.lerp(Color(0.74, 0.76, 0.79), 0.55)  # 不可点击变灰
	face_tint = face_tint.darkened(depth_shade)

	# 底座：基础色 + 强调色混合
	var chassis_tint: Color = chassis_color.lerp(accent_color.darkened(0.15), 0.18)
	if not is_clickable:
		chassis_tint = chassis_tint.lerp(Color(0.44, 0.46, 0.49), 0.35)
	chassis_tint = chassis_tint.darkened(depth_shade + 0.06)

	# 阴影：高层牌阴影更浓，发光时也更明显
	var shadow_alpha: float = 0.18 + 0.18 * glow_strength + 0.05 * minf(float(elevation_level), 2.0)
	var shadow_color: Color = Color(0.02, 0.03, 0.05, shadow_alpha)
	if not is_clickable:
		shadow_color = Color(0.02, 0.03, 0.05, 0.12 + 0.04 * minf(float(elevation_level), 2.0))

	# 边缘色
	var edge_tint: Color = edge_color.lerp(accent_color.darkened(0.30), 0.30 + glow_strength * 0.15)
	# 边框色：选中时混入更多强调色
	var border_tint: Color = edge_tint
	if is_selected:
		border_tint = border_tint.lerp(accent_color.lightened(0.25), 0.45)

	# ── 1. 外发光（选中/悬停时出现） ──
	if glow_strength > 0.01:
		_draw_box(
			face_rect.grow(6.0 + glow_strength * 10.0),
			Color(accent_color.r, accent_color.g, accent_color.b, 0.05 * glow_strength),
			Color(accent_color.r, accent_color.g, accent_color.b, 0.24 * glow_strength),
			18,
			2
		)

	# ── 2. 阴影 ──
	if show_shadow:
		_draw_box(shadow_rect, shadow_color, Color(0, 0, 0, 0), CHASSIS_CORNER, 0)

	# ── 3. 一体式底座（含厚度边带） ──
	_draw_box(base_rect, chassis_tint, edge_tint.darkened(0.12), CHASSIS_CORNER, 2)

	# ── 4. 正面 ──
	_draw_box(face_rect, face_tint, border_tint, FACE_CORNER, 2)

	# ── 6. 顶部装饰条（牌的"额头"） ──
	var top_band: Rect2 = Rect2(face_rect.position + Vector2(6.0, 6.0), Vector2(face_rect.size.x - 12.0, 6.0))
	draw_rect(top_band, Color(accent_color.r, accent_color.g, accent_color.b, 0.44 + glow_strength * 0.12), true)

	# ── 7. 高光（左上角的光泽反射） ──
	# 一个半透明多边形，模拟塑料/骨牌材质的光泽
	var gloss_polygon: PackedVector2Array = PackedVector2Array([
		face_rect.position + Vector2(8.0, 8.0),
		face_rect.position + Vector2(face_rect.size.x - 12.0, 8.0),
		face_rect.position + Vector2(face_rect.size.x * 0.58, face_rect.size.y * 0.44),
		face_rect.position + Vector2(8.0, face_rect.size.y * 0.30),
	])
	draw_colored_polygon(gloss_polygon, Color(1, 1, 1, 0.08 + _shine_amount * 0.18))

	# ── 8. 内阴影（正面底部的微弱暗区，增加立体感） ──
	var inner_shadow: Rect2 = Rect2(face_rect.position + Vector2(8.0, face_rect.size.y * 0.62), Vector2(face_rect.size.x - 16.0, face_rect.size.y * 0.22))
	draw_rect(inner_shadow, Color(0.12, 0.16, 0.20, 0.05), true)

	# ── 9. 图标（牌的图案） ──
	_draw_icon(face_rect)

	# ── 10. 错误点击警告覆盖层（红色边框） ──
	if _warning_amount > 0.01:
		_draw_box(
			face_rect.grow(1.0),
			Color(1.0, 0.38, 0.32, 0.12 * _warning_amount),
			Color(1.0, 0.45, 0.36, 0.28 * _warning_amount),
			FACE_CORNER + 1,
			2
		)

	# ── 11. 消除闪光覆盖层（金色边框） ──
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


# ═══════════════════════════════════════════════════════════════
# _update_visual_state: 用 Tween 平滑过渡所有视觉效果
# ═══════════════════════════════════════════════════════════════
# 根据当前状态（选中/悬停/高亮/按下）计算目标值，
# 然后用 Tween 动画让 _lift_amount、_glow_amount 等平滑变化
func _update_visual_state() -> void:
	if is_removed:
		return

	_kill_tween(_state_tween)

	# ── 目标抬起高度 ──
	var target_lift := 0.0
	if is_selected:
		target_lift = 1.0           # 选中时完全抬起
	elif hover_active and is_clickable:
		target_lift = 0.45          # 悬停时半抬起

	# ── 目标发光强度 ──
	var target_glow := 0.0
	if is_selected:
		target_glow = 0.95
	elif hover_active and is_clickable:
		target_glow = 0.40

	# ── 目标高光强度 ──
	var target_shine := 0.28
	if is_selected:
		target_shine = 0.75
	elif hover_active and is_clickable:
		target_shine = 0.55

	# ── 目标缩放 ──
	var target_multiplier := Vector2.ONE
	if is_selected:
		target_multiplier = Vector2(1.08, 1.08)   # 选中时放大 8%
	elif hover_active and is_clickable:
		target_multiplier = Vector2(1.03, 1.03)   # 悬停时放大 3%

	# 高亮状态：至少保证这些最小值
	if is_highlighted and not is_selected:
		target_lift = maxf(target_lift, 0.32)
		target_glow = maxf(target_glow, 0.70)
		target_shine = maxf(target_shine, 0.65)
		target_multiplier = Vector2(maxf(target_multiplier.x, 1.05), maxf(target_multiplier.y, 1.05))

	# 按下时略微压扁（模拟物理按压）
	if is_pressing and is_clickable:
		target_multiplier *= Vector2(0.985, 0.94)

	var target_scale := base_scale * target_multiplier

	# ── 目标旋转 ──
	var target_rotation := 0.0
	if is_selected:
		target_rotation = -1.2       # 选中时微微左倾
	elif hover_active and is_clickable:
		target_rotation = -0.5       # 悬停时微微左倾
	if is_highlighted and not is_selected:
		target_rotation = minf(target_rotation, -0.45)

	# ── 启动 Tween 动画 ──
	_state_tween = create_tween()
	_state_tween.set_parallel(true)   # 所有属性同时动画
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


# ── 根据材质和牌型应用颜色调色板 ──
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


# ═══════════════════════════════════════════════════════════════
# 绘制辅助函数
# ═══════════════════════════════════════════════════════════════

# 绘制圆角矩形盒子（使用 Godot 的 StyleBoxFlat）
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


# 绘制牌的图标（麻将图案）
func _draw_icon(face_rect: Rect2) -> void:
	if tile_icon == null:
		return

	# 图标区域：正面内边距后的居中区域
	var icon_area: Rect2 = Rect2(face_rect.position + Vector2(8.0, 14.0), face_rect.size - Vector2(16.0, 24.0))
	var texture_size: Vector2 = tile_icon.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	# 等比例缩放，填满 76% 的区域（发光时稍大一点）
	var fill_ratio: float = 0.76 + _glow_amount * 0.04
	var scale_factor: float = minf(icon_area.size.x / texture_size.x, icon_area.size.y / texture_size.y) * fill_ratio
	var draw_size: Vector2 = texture_size * scale_factor
	var icon_draw_rect: Rect2 = Rect2(icon_area.position + (icon_area.size - draw_size) * 0.5, draw_size)

	# 不可点击时图标变暗
	var icon_modulate := Color(1, 1, 1, 0.96 if is_clickable else 0.60)
	if is_selected:
		icon_modulate = icon_modulate.lerp(Color(accent_color.r, accent_color.g, accent_color.b, icon_modulate.a), 0.16)
	if _warning_amount > 0.01:
		icon_modulate = icon_modulate.lerp(Color(1.0, 0.74, 0.70, icon_modulate.a), 0.20 * _warning_amount)

	# 绘制图标本体
	draw_texture_rect(tile_icon, icon_draw_rect, false, icon_modulate)
	# 绘制微弱的外发光轮廓
	draw_texture_rect(tile_icon, icon_draw_rect.grow(1.0), false, Color(1, 1, 1, 0.03 + _glow_amount * 0.06))


# ── 根据牌型获取强调色 ──
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


# ── 根据材质名称获取色调 ──
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


# ── 获取透明占位纹理（隐藏默认按钮图片） ──
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
