extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# TileDemo: 2.5D 牌效果交互演示场景
# 
# 用途：
#   1. 教学演示：逐层展示 2.5D 牌的绘制过程
#   2. 效果调试：实时调节参数，观察视觉效果变化
#   3. 展示 Godot 2D 能力：自定义绘制、Tween动画、UI系统
# 
# 操作说明：
#   - 点击"下一步/上一步"逐层查看绘制过程
#   - 调节滑块观察动态效果
#   - 勾选"线框模式"查看几何结构
#   - 点击"自动播放"观看完整构建动画
# ═══════════════════════════════════════════════════════════════════════════════

const STEP_COUNT := 10
const STEP_NAMES: Array[String] = [
	"步骤 0：空白画布",
	"步骤 1：阴影层",
	"步骤 2：底盘（厚度顶面）",
	"步骤 3：厚度侧面（2.5D 核心）",
	"步骤 4：正面（牌面主体）",
	"步骤 5：顶部装饰条",
	"步骤 6：高光反射",
	"步骤 7：内阴影",
	"步骤 8：牌面图标",
	"步骤 9：外发光（交互反馈）",
]

const STEP_DESCRIPTIONS: Array[String] = [
	"_draw() 开始执行，画布为空。所有视觉元素即将逐层叠加。",
	"绘制阴影：Rect2 + SHADOW_OFFSET 偏移（右10px, 下14px）。\n模拟光源在左上方，牌悬空于桌面之上。",
	"绘制底盘：正面 + TILE_DEPTH 偏移（右8px, 下10px）。\n底盘与正面错开，肉眼自动脑补出\"厚度\"。",
	"绘制侧面多边形：用 PackedVector2Array 连接正面和底盘的边缘。\n这是 2.5D 的灵魂——没有侧面，牌就是平的。",
	"绘制正面：圆角矩形 + 边框。\n这是玩家实际看到的游戏区域，所有交互围绕它发生。",
	"绘制顶部装饰条：一条彩色横条。\n不同牌组有不同颜色（风牌=蓝灰，花牌=金黄），快速识别牌型。",
	"绘制高光：不规则四边形 + 半透明白色。\n模拟塑料/骨牌材质的光泽反射，增加真实感。",
	"绘制内阴影：正面底部的微弱暗区。\n营造凹陷感，让牌面看起来像微微内凹。",
	"绘制图标：加载外部纹理，等比例缩放居中。\n这是唯一使用外部资源的层，其余全是代码绘制。",
	"绘制外发光：face_rect.grow() 扩展 + 半透明边框。\n选中/悬停时的视觉反馈：\"我可以点击！\"",
]

const STEP_CODES: Array[String] = [
	"func _draw():\n    pass  # 画布为空",
	"var shadow_rect = Rect2(\n    chassis_rect.position + SHADOW_OFFSET,\n    TILE_SIZE)\n_draw_rounded_rect(\n    shadow_rect, shadow_color, ...)",
	"var chassis_rect = Rect2(\n    face_origin + TILE_DEPTH,\n    TILE_SIZE)\n_draw_rounded_rect(\n    chassis_rect, chassis_color, ...)",
	"var right_side = PackedVector2Array([\n    face_rect.top_right,\n    chassis_rect.top_right,\n    chassis_rect.bottom_right,\n    face_rect.bottom_right])\ndraw_colored_polygon(right_side, dark_color)",
	"var face_rect = Rect2(\n    face_origin, TILE_SIZE)\n_draw_rounded_rect(\n    face_rect, face_color,\n    edge_color, FACE_CORNER, 2)",
	"var top_band = Rect2(\n    face_rect.position + Vector2(6, 6),\n    Vector2(face_rect.size.x - 12, 6))\ndraw_rect(top_band, accent_color)",
	"var gloss = PackedVector2Array([\n    face_rect.position + Vector2(8, 8),\n    ...])\ndraw_colored_polygon(\n    gloss, Color(1,1,1,0.08))",
	"var inner = Rect2(\n    face_rect.position + Vector2(8, h*0.62),\n    Vector2(w-16, h*0.22))\ndraw_rect(inner, Color(0.12,0.16,0.20,0.05))",
	"var icon_rect = Rect2(...)\ndraw_texture_rect(\n    tile_icon, icon_rect,\n    false, Color.white)",
	"var glow_rect = face_rect.grow(\n    6.0 + glow * 10.0)\n_draw_rounded_rect(\n    glow_rect, glow_fill,\n    glow_border, 18, 2)",
]

@onready var drawer: Control = %TileDemoDrawer
@onready var step_label: Label = %StepLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var code_label: RichTextLabel = %CodeLabel
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var auto_button: Button = %AutoButton
@onready var step_slider: HSlider = %StepSlider
@onready var lift_slider: HSlider = %LiftSlider
@onready var glow_slider: HSlider = %GlowSlider
@onready var shine_slider: HSlider = %ShineSlider
@onready var wireframe_check: CheckBox = %WireframeCheck
@onready var accent_color_btn: Button = %AccentColorButton
@onready var material_selector: OptionButton = %MaterialSelector
@onready var status_label: Label = %StatusLabel
@onready var lift_value_label: Label = %LiftValue
@onready var glow_value_label: Label = %GlowValue
@onready var shine_value_label: Label = %ShineValue

var _auto_playing: bool = false
var _auto_tween: Tween


func _ready() -> void:
	# 连接控件信号
	prev_button.pressed.connect(_on_prev_step)
	next_button.pressed.connect(_on_next_step)
	auto_button.pressed.connect(_on_auto_play)
	step_slider.value_changed.connect(_on_step_slider_changed)
	lift_slider.value_changed.connect(_on_lift_slider_changed)
	glow_slider.value_changed.connect(_on_glow_slider_changed)
	shine_slider.value_changed.connect(_on_shine_slider_changed)
	wireframe_check.toggled.connect(_on_wireframe_toggled)
	accent_color_btn.pressed.connect(_on_accent_color_pressed)
	material_selector.item_selected.connect(_on_material_selected)
	
	# 初始化材质选择器
	_material_selector_setup()
	
	# 初始更新
	_update_display()
	_update_drawer()


func _on_prev_step() -> void:
	_auto_stop()
	if drawer.step_index > 0:
		drawer.step_index -= 1
		_animate_step_change()
		_update_display()
		_update_drawer()


func _on_next_step() -> void:
	_auto_stop()
	if drawer.step_index < STEP_COUNT - 1:
		drawer.step_index += 1
		_animate_step_change()
		_update_display()
		_update_drawer()


func _on_auto_play() -> void:
	if _auto_playing:
		_auto_stop()
		return
	
	_auto_playing = true
	auto_button.text = "停止播放"
	drawer.step_index = 0
	_update_display()
	_update_drawer()
	
	# 使用 Tween 链式动画自动切换步骤
	_auto_tween = create_tween()
	for i in range(1, STEP_COUNT):
		_auto_tween.tween_callback(func():
			drawer.step_index = i
			_update_display()
			_update_drawer()
		)
		_auto_tween.tween_interval(1.2)
	_auto_tween.tween_callback(_auto_stop)


func _auto_stop() -> void:
	_auto_playing = false
	auto_button.text = "自动播放"
	if _auto_tween != null and _auto_tween.is_valid():
		_auto_tween.kill()


func _animate_step_change() -> void:
	# 步骤切换时给 drawer 一个轻微的缩放反馈
	var tween := create_tween()
	tween.tween_property(drawer, "scale", Vector2(1.03, 1.03), 0.06)
	tween.tween_property(drawer, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_step_slider_changed(value: float) -> void:
	_auto_stop()
	drawer.step_index = int(value)
	_update_display()
	_update_drawer()


func _on_lift_slider_changed(value: float) -> void:
	drawer.lift_amount = value / 100.0
	drawer.queue_redraw()
	lift_value_label.text = "%.0f%%" % value
	status_label.text = "抬起高度: %.0f%%" % value


func _on_glow_slider_changed(value: float) -> void:
	drawer.glow_amount = value / 100.0
	drawer.queue_redraw()
	glow_value_label.text = "%.0f%%" % value
	status_label.text = "发光强度: %.0f%%" % value


func _on_shine_slider_changed(value: float) -> void:
	drawer.shine_amount = value / 100.0
	drawer.queue_redraw()
	shine_value_label.text = "%.0f%%" % value
	status_label.text = "高光强度: %.0f%%" % value


func _on_wireframe_toggled(value: bool) -> void:
	drawer.show_wireframe = value
	drawer.queue_redraw()


func _on_accent_color_pressed() -> void:
	# 循环切换几种强调色，展示不同牌组的配色
	var colors := [
		Color(0.22, 0.65, 0.40),  # 默认绿（条子）
		Color(0.44, 0.53, 0.62),  # 蓝灰（风牌）
		Color(0.90, 0.66, 0.22),  # 金黄（花牌）
		Color(0.84, 0.30, 0.28),  # 红色（万子）
		Color(0.28, 0.48, 0.82),  # 蓝色（筒子）
	]
	var current_idx := colors.find(drawer.accent_color)
	var next_idx := (current_idx + 1) % colors.size()
	drawer.accent_color = colors[next_idx]
	drawer.queue_redraw()
	status_label.text = "强调色已切换"


func _on_material_selected(index: int) -> void:
	var tints := [
		Color(0.84, 0.79, 0.70),  # bone
		Color(0.92, 0.72, 0.26),  # topaz
		Color(0.31, 0.51, 0.84),  # sapphire
		Color(0.70, 0.34, 0.30),  # garnet
		Color(0.85, 0.22, 0.26),  # ruby
		Color(0.38, 0.72, 0.60),  # jade
		Color(0.16, 0.58, 0.36),  # emerald
	]
	if index < tints.size():
		drawer.face_color = Color(0.97, 0.95, 0.90).lerp(tints[index].lightened(0.80), 0.14)
		drawer.chassis_color = Color(0.85, 0.79, 0.69).lerp(tints[index], 0.24)
		drawer.edge_color = drawer.chassis_color.darkened(0.42)
		drawer.queue_redraw()


func _material_selector_setup() -> void:
	var materials := ["bone", "topaz", "sapphire", "garnet", "ruby", "jade", "emerald"]
	for i in range(materials.size()):
		material_selector.add_item(materials[i], i)


func _update_display() -> void:
	var idx: int = drawer.step_index
	step_label.text = STEP_NAMES[idx]
	description_label.text = STEP_DESCRIPTIONS[idx]
	code_label.text = "[code]" + STEP_CODES[idx] + "[/code]"
	step_slider.value = idx
	
	prev_button.disabled = idx <= 0
	next_button.disabled = idx >= STEP_COUNT - 1


func _update_drawer() -> void:
	drawer.queue_redraw()
