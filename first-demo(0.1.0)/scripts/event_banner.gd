extends CanvasLayer
class_name EventBanner

## 关卡开场特殊事件横幅
## 用法：由 board.gd 在 _activate_round_event() 里调用 EventBanner.show_event(parent, event_type, callback)
## 动画播完后自动销毁自身，并调用 on_done 回调（允许 null）。

signal banner_dismissed

const SLIDE_IN_TIME   := 0.38      ## 从屏幕上方滑入的时间
const HOLD_TIME       := 1.5       ## 停留时间
const SLIDE_OUT_TIME  := 0.32      ## 滑出时间
const PULSE_SCALE     := 1.06      ## 标题脉冲放大系数

var _on_done: Callable = Callable()

# ── 工厂方法（由外部调用） ─────────────────────────────────────────────────────
static func show_event(parent: Node, event_type: String, on_done: Callable = Callable()) -> void:
	if event_type == EventManager.EVENT_NONE:
		if on_done.is_valid():
			on_done.call()
		return

	var banner := EventBanner.new()
	banner._on_done = on_done
	parent.add_child(banner)
	banner._build_and_animate(event_type)


# ── 私有构建 ─────────────────────────────────────────────────────────────────
func _build_and_animate(event_type: String) -> void:
	layer = 128  # 浮于所有 UI 之上

	var vp_size := get_viewport().get_visible_rect().size
	var panel_h := 150.0
	# 限制最大宽度，避免在大屏幕上过宽
	var panel_w := minf(vp_size.x * 0.80, 660.0)
	var panel_x := (vp_size.x - panel_w) * 0.5
	# 居中：面板出现在屏幕正中央
	var panel_y := (vp_size.y - panel_h) * 0.5

	# ── 全屏半透明遮罩 ──
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.position = Vector2.ZERO
	overlay.size = vp_size
	add_child(overlay)

	# ── 主面板（从屏幕上方进入） ──
	var panel := Panel.new()
	panel.position = Vector2(panel_x, -panel_h - 30.0)
	panel.size = Vector2(panel_w, panel_h)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = EventManager.get_event_banner_color(event_type)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = EventManager.get_event_hud_color(event_type)
	panel_style.shadow_size = 14
	panel_style.shadow_color = Color(0, 0, 0, 0.55)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# ── 内容：MarginContainer + VBoxContainer，避免 anchor 冲突 ──
	var margin := MarginContainer.new()
	margin.position = Vector2.ZERO
	margin.size = Vector2(panel_w, panel_h)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── 标题标签 ──
	var title_label := Label.new()
	title_label.text = EventManager.get_event_display_name(event_type)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", EventManager.get_event_hud_color(event_type))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title_label)

	# ── 装饰分隔线 ──
	var sep := ColorRect.new()
	sep.color = EventManager.get_event_hud_color(event_type)
	sep.color.a = 0.5
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	# ── 描述标签 ──
	var desc_label := Label.new()
	desc_label.text = EventManager.get_event_description(event_type)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 0.95))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	# ── 动画序列 ──
	var target_y: float = panel_y
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# 遮罩淡入（与滑入同步）
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.38), SLIDE_IN_TIME * 0.6)
	tween.set_parallel(true)

	# 面板从上方滑入
	tween.tween_property(panel, "position:y", target_y, SLIDE_IN_TIME)

	# 标题脉冲
	tween.chain()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "scale", Vector2(PULSE_SCALE, PULSE_SCALE), 0.18) \
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.18) \
		.set_trans(Tween.TRANS_BACK)

	# 停留
	tween.tween_interval(HOLD_TIME)

	# 面板向上滑出
	tween.chain().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "position:y", -panel_h - 30.0, SLIDE_OUT_TIME)
	tween.set_parallel(true)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.0), SLIDE_OUT_TIME)

	# 销毁
	tween.chain().tween_callback(_finish)


func _finish() -> void:
	banner_dismissed.emit()
	if _on_done.is_valid():
		_on_done.call()
	queue_free()
