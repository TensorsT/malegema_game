extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# TileDemoDrawer: 2.5D 牌的逐层绘制演示器
# 
# 这个节点通过 _draw() 自定义绘制，演示如何用纯代码构建一张立体麻将牌。
# 核心教学点：
#   - 分层绘制（Painter's Algorithm：从后往前画）
#   - 矩形偏移制造"厚度"错觉
#   - 颜色混合模拟光照
#   - 多边形绘制连接不同平面
# ═══════════════════════════════════════════════════════════════════════════════

# ── 尺寸常量 ──
const TILE_SIZE := Vector2(64, 96)
const TILE_DEPTH := Vector2(8, 10)
const SHADOW_OFFSET := Vector2(10, 14)
const FACE_CORNER := 12
const CHASSIS_CORNER := 14

# ── 可调节参数（由外部控制面板修改） ──
var step_index: int = 0          # 当前展示的绘制步骤（0~9）
var lift_amount: float = 0.0     # 抬起高度（0.0~1.0）
var glow_amount: float = 0.0     # 发光强度（0.0~1.0）
var shine_amount: float = 0.28   # 高光强度（0.0~1.0）
var show_wireframe: bool = false # 是否显示线框（帮助理解几何结构）

# ── 颜色调色板 ──
var accent_color := Color(0.22, 0.65, 0.40)
var face_color := Color(0.97, 0.95, 0.90)
var chassis_color := Color(0.85, 0.79, 0.69)
var edge_color := Color(0.45, 0.39, 0.32)

# ── 图标纹理 ──
var tile_icon: Texture2D = null


func _ready() -> void:
	# 设置节点大小为绘制区域
	custom_minimum_size = Vector2(200, 200)
	size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 尝试加载一张示例图标
	var icon_path := "res://tiles/bam1.webp"
	if ResourceLoader.exists(icon_path):
		tile_icon = load(icon_path) as Texture2D


# ═══════════════════════════════════════════════════════════════════════════════
# 核心：_draw() —— 根据 step_index 决定绘制哪些层
# ═══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	var center := size * 0.5
	var face_origin := center - TILE_SIZE * 0.5 + Vector2(0, -lerpf(0, 14, lift_amount))
	var face_rect := Rect2(face_origin, TILE_SIZE)
	var chassis_rect := Rect2(face_origin + TILE_DEPTH, TILE_SIZE)
	var shadow_rect := Rect2(chassis_rect.position + SHADOW_OFFSET, TILE_SIZE)
	
	var glow_strength := clampf(glow_amount + 0.08, 0, 1.15)
	
	# 根据步骤索引，逐步添加绘制层
	# 每一步都在前一步的基础上增加新内容
	
	# 步骤 0：什么都没有（空白画布）
	if step_index < 1:
		_draw_step_label(center, "步骤 0：空白画布\n_draw() 开始执行")
		return
	
	# 步骤 1：绘制阴影
	_draw_shadow(shadow_rect, glow_strength)
	if step_index == 1:
		_draw_step_label(center, "步骤 1：阴影层\nRect2 + SHADOW_OFFSET\n模拟光源在左上方")
		_highlight_rect(shadow_rect, Color.YELLOW)
		return
	
	# 步骤 2：绘制底盘（厚度顶面）
	_draw_chassis(chassis_rect, glow_strength)
	if step_index == 2:
		_draw_step_label(center, "步骤 2：底盘（厚度顶面）\n正面 + TILE_DEPTH 偏移\n营造厚度错觉")
		_highlight_rect(chassis_rect, Color.CYAN)
		return
	
	# 步骤 3：绘制厚度侧面（关键！连接正面和底盘）
	_draw_side_polygons(face_rect, chassis_rect)
	if step_index == 3:
		_draw_step_label(center, "步骤 3：厚度侧面（2.5D 核心）\n多边形连接正面与底盘\n没有侧面就没有立体感")
		_highlight_side_polygons(face_rect, chassis_rect, Color.ORANGE)
		return
	
	# 步骤 4：绘制正面
	_draw_face(face_rect, glow_strength)
	if step_index == 4:
		_draw_step_label(center, "步骤 4：正面（牌面主体）\n圆角矩形 + 边框\n实际可见的游戏区域")
		_highlight_rect(face_rect, Color.GREEN)
		return
	
	# 步骤 5：添加顶部装饰条
	_draw_top_band(face_rect, glow_strength)
	if step_index == 5:
		_draw_step_label(center, "步骤 5：顶部装饰条\n彩色额头条标识牌组\n风牌 = 蓝灰, 花牌 = 金黄")
		return
	
	# 步骤 6：添加高光（材质感）
	_draw_gloss(face_rect)
	if step_index == 6:
		_draw_step_label(center, "步骤 6：高光反射\n不规则多边形 + 半透明白\n模拟塑料/骨牌光泽")
		return
	
	# 步骤 7：添加内阴影（深度感）
	_draw_inner_shadow(face_rect)
	if step_index == 7:
		_draw_step_label(center, "步骤 7：内阴影\n底部暗区营造凹陷感\n增加正面层次")
		return
	
	# 步骤 8：绘制图标
	_draw_icon(face_rect)
	if step_index == 8:
		_draw_step_label(center, "步骤 8：牌面图标\n外部纹理贴图\n等比例缩放居中")
		return
	
	# 步骤 9：完整效果 + 外发光
	_draw_outer_glow(face_rect, glow_strength)
	if step_index >= 9:
		_draw_step_label(center, "步骤 9：外发光（选中/悬停）\ngrow() 扩展 + 半透明边框\n视觉反馈：我可以点击！")
	
	# 线框模式：绘制几何辅助线帮助理解
	if show_wireframe:
		_draw_wireframe(face_rect, chassis_rect, shadow_rect)


# ── 各层的独立绘制函数 ──

func _draw_shadow(shadow_rect: Rect2, glow_strength: float) -> void:
	var alpha := 0.18 + 0.18 * glow_strength
	var shadow_color := Color(0.02, 0.03, 0.05, alpha)
	_draw_rounded_rect(shadow_rect, shadow_color, Color.TRANSPARENT, CHASSIS_CORNER, 0)


func _draw_chassis(chassis_rect: Rect2, glow_strength: float) -> void:
	var chassis_tint := chassis_color.lerp(accent_color.darkened(0.15), 0.18)
	var edge_tint := edge_color.lerp(accent_color.darkened(0.30), 0.30 + glow_strength * 0.15)
	_draw_rounded_rect(chassis_rect, chassis_tint, edge_tint.darkened(0.12), CHASSIS_CORNER, 2)


func _draw_side_polygons(face_rect: Rect2, chassis_rect: Rect2) -> void:
	var right_side := PackedVector2Array([
		face_rect.position + Vector2(face_rect.size.x, 0),
		chassis_rect.position + Vector2(chassis_rect.size.x, 0),
		chassis_rect.position + chassis_rect.size,
		face_rect.position + face_rect.size,
	])
	var bottom_side := PackedVector2Array([
		face_rect.position + Vector2(0, face_rect.size.y),
		face_rect.position + face_rect.size,
		chassis_rect.position + chassis_rect.size,
		chassis_rect.position + Vector2(0, chassis_rect.size.y),
	])
	
	# 右侧面更暗（背光），底侧面稍暗
	draw_colored_polygon(right_side, chassis_color.darkened(0.14))
	draw_colored_polygon(bottom_side, chassis_color.darkened(0.05))
	draw_polyline(right_side, edge_color.darkened(0.30), 2.0, true)
	draw_polyline(bottom_side, edge_color.darkened(0.30), 2.0, true)


func _draw_face(face_rect: Rect2, glow_strength: float) -> void:
	var face_tint := face_color.lerp(accent_color.lightened(0.82), 0.06 + glow_strength * 0.08)
	var edge_tint := edge_color.lerp(accent_color.darkened(0.30), 0.30 + glow_strength * 0.15)
	_draw_rounded_rect(face_rect, face_tint, edge_tint, FACE_CORNER, 2)


func _draw_top_band(face_rect: Rect2, glow_strength: float) -> void:
	var top_band := Rect2(
		face_rect.position + Vector2(6, 6),
		Vector2(face_rect.size.x - 12, 6)
	)
	draw_rect(top_band, Color(accent_color.r, accent_color.g, accent_color.b, 0.44 + glow_strength * 0.12), true)


func _draw_gloss(face_rect: Rect2) -> void:
	var gloss := PackedVector2Array([
		face_rect.position + Vector2(8, 8),
		face_rect.position + Vector2(face_rect.size.x - 12, 8),
		face_rect.position + Vector2(face_rect.size.x * 0.58, face_rect.size.y * 0.44),
		face_rect.position + Vector2(8, face_rect.size.y * 0.30),
	])
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.08 + shine_amount * 0.18))


func _draw_inner_shadow(face_rect: Rect2) -> void:
	var inner := Rect2(
		face_rect.position + Vector2(8, face_rect.size.y * 0.62),
		Vector2(face_rect.size.x - 16, face_rect.size.y * 0.22)
	)
	draw_rect(inner, Color(0.12, 0.16, 0.20, 0.05), true)


func _draw_icon(face_rect: Rect2) -> void:
	if tile_icon == null:
		return
	var icon_area := Rect2(face_rect.position + Vector2(8, 14), face_rect.size - Vector2(16, 24))
	var tex_size := tile_icon.get_size()
	var scale_factor := minf(icon_area.size.x / tex_size.x, icon_area.size.y / tex_size.y) * 0.76
	var draw_size := tex_size * scale_factor
	var icon_rect := Rect2(icon_area.position + (icon_area.size - draw_size) * 0.5, draw_size)
	draw_texture_rect(tile_icon, icon_rect, false, Color(1, 1, 1, 0.96))


func _draw_outer_glow(face_rect: Rect2, glow_strength: float) -> void:
	if glow_strength <= 0.01:
		return
	var glow_rect := face_rect.grow(6.0 + glow_strength * 10.0)
	var fill := Color(accent_color.r, accent_color.g, accent_color.b, 0.05 * glow_strength)
	var border := Color(accent_color.r, accent_color.g, accent_color.b, 0.24 * glow_strength)
	_draw_rounded_rect(glow_rect, fill, border, 18, 2)


# ── 辅助绘制函数 ──

func _draw_rounded_rect(rect: Rect2, fill: Color, border: Color, radius: int, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.border_color = border
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_width_left = border_width
		style.border_width_right = border_width
	draw_style_box(style, rect)


func _draw_step_label(center: Vector2, text: String) -> void:
	# 在底部绘制当前步骤的说明文字
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(center.x - text_size.x * 0.5, size.y - 20)
	# 文字阴影
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.5))
	# 文字本体
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _highlight_rect(rect: Rect2, color: Color) -> void:
	# 用虚线框高亮某个矩形，帮助理解当前步骤
	var dash_length := 6.0
	var gap_length := 4.0
	var points := _get_dashed_rect_points(rect, dash_length, gap_length)
	for i in range(0, points.size(), 2):
		if i + 1 < points.size():
			draw_line(points[i], points[i + 1], color, 2.0, true)


func _get_dashed_rect_points(rect: Rect2, dash: float, gap: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var perimeter := rect.size.x * 2 + rect.size.y * 2
	var segments := int(perimeter / (dash + gap)) + 1
	
	for i in range(segments):
		var t0 := float(i) * (dash + gap) / perimeter
		var t1 := (float(i) * (dash + gap) + dash) / perimeter
		if t1 > 1.0:
			t1 = 1.0
		points.append(_get_rect_point(rect, t0))
		points.append(_get_rect_point(rect, t1))
	
	return points


func _get_rect_point(rect: Rect2, t: float) -> Vector2:
	# t: 0~1 沿矩形周长归一化
	var p := rect.position
	var s := rect.size
	var perimeter := s.x * 2 + s.y * 2
	var dist := t * perimeter
	
	if dist < s.x:
		return p + Vector2(dist, 0)
	dist -= s.x
	if dist < s.y:
		return p + Vector2(s.x, dist)
	dist -= s.y
	if dist < s.x:
		return p + Vector2(s.x - dist, s.y)
	dist -= s.x
	return p + Vector2(0, s.y - dist)


func _highlight_side_polygons(face_rect: Rect2, chassis_rect: Rect2, color: Color) -> void:
	# 高亮侧面的多边形顶点
	var right_pts := [
		face_rect.position + Vector2(face_rect.size.x, 0),
		chassis_rect.position + Vector2(chassis_rect.size.x, 0),
		chassis_rect.position + chassis_rect.size,
		face_rect.position + face_rect.size,
	]
	for i in range(right_pts.size()):
		var a: Vector2 = right_pts[i]
		var b: Vector2 = right_pts[(i + 1) % right_pts.size()]
		draw_line(a, b, color, 3.0, true)
		draw_circle(a, 4.0, color)
	
	var bottom_pts := [
		face_rect.position + Vector2(0, face_rect.size.y),
		face_rect.position + face_rect.size,
		chassis_rect.position + chassis_rect.size,
		chassis_rect.position + Vector2(0, chassis_rect.size.y),
	]
	for i in range(bottom_pts.size()):
		var a: Vector2 = bottom_pts[i]
		var b: Vector2 = bottom_pts[(i + 1) % bottom_pts.size()]
		draw_line(a, b, Color(color.r, color.g, color.b, 0.6), 2.0, true)
		draw_circle(a, 3.0, Color(color.r, color.g, color.b, 0.6))


func _draw_wireframe(face_rect: Rect2, chassis_rect: Rect2, shadow_rect: Rect2) -> void:
	# 绘制辅助线框，展示三个矩形的空间关系
	draw_rect(face_rect, Color.TRANSPARENT, false, 1.0)
	draw_rect(chassis_rect, Color.TRANSPARENT, false, 1.0)
	draw_rect(shadow_rect, Color.TRANSPARENT, false, 1.0)
	
	# 连接线：正面 → 底盘
	draw_line(face_rect.position, chassis_rect.position, Color(1, 1, 1, 0.3), 1.0, true)
	draw_line(face_rect.position + Vector2(face_rect.size.x, 0), 
		chassis_rect.position + Vector2(chassis_rect.size.x, 0), Color(1, 1, 1, 0.3), 1.0, true)
	
	# 标签
	var font := ThemeDB.fallback_font
	draw_string(font, face_rect.position + Vector2(2, -4), "正面 (face)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.GREEN)
	draw_string(font, chassis_rect.position + Vector2(2, -4), "底盘 (chassis)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.CYAN)
	draw_string(font, shadow_rect.position + Vector2(2, -4), "阴影 (shadow)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
