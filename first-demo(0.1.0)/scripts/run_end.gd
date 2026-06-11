extends Control

@onready var end_panel: Panel = $EndPanel
@onready var title_label: Label = $EndPanel/VBoxContainer/TitleLabel
@onready var summary_label: Label = $EndPanel/VBoxContainer/SummaryLabel
@onready var action_button: Button = $EndPanel/VBoxContainer/NewRunButton

const ENTRANCE_SLIDE := 64.0

var _celebration_layer: Control
var _lines_box: VBoxContainer
var _coin_style: StyleBoxFlat
var _spark_style: StyleBoxFlat
var _confetti_style: StyleBoxFlat

const CONFETTI_PALETTE: Array[Color] = [
	Color(1.0, 0.80, 0.16, 1.0),
	Color(0.86, 0.32, 0.24, 1.0),
	Color(0.34, 0.60, 0.86, 1.0),
	Color(0.42, 0.66, 0.34, 1.0),
	Color(0.96, 0.93, 0.78, 1.0),
]


func _ready() -> void:
	_apply_ui()
	_setup_celebration_layer()
	_setup_lines_box()
	# 初始状态：面板完全透明，由入场动画逐步显示
	end_panel.modulate.a = 0.0
	end_panel.position.y += ENTRANCE_SLIDE
	title_label.modulate.a = 0.0
	summary_label.modulate.a = 0.0
	action_button.modulate.a = 0.0
	summary_label.text = ""
	_play_entrance_animation()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(end_panel, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(action_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_button(action_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_BAM.darkened(0.35))
	WhatajongUI.tint_body_text(summary_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)


func _setup_celebration_layer() -> void:
	_celebration_layer = Control.new()
	_celebration_layer.name = "CelebrationLayer"
	_celebration_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_celebration_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration_layer.z_index = 8
	end_panel.add_child(_celebration_layer)

	_coin_style = _make_disc_style(Color(1.0, 0.80, 0.16, 0.92), Color(0.78, 0.48, 0.05, 0.9))
	_spark_style = _make_disc_style(Color(1.0, 0.96, 0.58, 0.8), Color(0.92, 0.76, 0.18, 0.6))
	_confetti_style = _make_confetti_style()


func _setup_lines_box() -> void:
	# 逐行结算文字使用独立 Label 节点承载，便于做单行弹入动画。
	_lines_box = VBoxContainer.new()
	_lines_box.name = "SummaryLines"
	_lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines_box.add_theme_constant_override("separation", 10)
	summary_label.add_child(_lines_box)


## -------------------------------------------------------------------------
## 入场动画
## -------------------------------------------------------------------------

func _play_entrance_animation() -> void:
	# 面板淡入 + 明显缩放（0.82 -> 1.0，带回弹）并从下方上浮归位。
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale = Vector2(0.82, 0.82)
	var panel_target_y := end_panel.position.y - ENTRANCE_SLIDE

	var tween := create_tween().set_parallel(true)
	tween.tween_property(end_panel, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(end_panel, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "position:y", panel_target_y, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 标题延迟弹入：从 1.45 倍缩小落定，类似盖章效果
	await get_tree().create_timer(0.18).timeout
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2(1.45, 1.45)
	var tween2 := create_tween().set_parallel(true)
	tween2.tween_property(title_label, "modulate:a", 1.0, 0.22)
	tween2.tween_property(title_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 延迟后填充结算文字（逐行弹入）
	await get_tree().create_timer(0.42).timeout
	_update_summary()

	# 按钮最后淡入并轻微上浮
	await get_tree().create_timer(0.55).timeout
	var tween3 := create_tween()
	tween3.tween_property(action_button, "modulate:a", 1.0, 0.28)


## -------------------------------------------------------------------------
## 结算内容
## -------------------------------------------------------------------------

func _update_summary() -> void:
	if _is_round_settlement():
		_update_round_summary()
		return
	_update_final_summary()


func _is_round_settlement() -> bool:
	return (
		RunManager.has_active_run()
		and String(RunManager.run.get("stage", "")) == RunManager.STAGE_SETTLEMENT
		and not RunManager.last_round_result.is_empty()
	)


func _update_round_summary() -> void:
	var result := RunManager.last_round_result
	var round_id := int(result.get("round", RunManager.run.get("round", 1)))
	var win := bool(result.get("win", false))
	var points := int(result.get("points", 0))
	var objective := int(result.get("objective", 0))
	var total_points := int(result.get("totalPoints", 0))
	var time := float(result.get("time", 0.0))
	var penalty := float(result.get("penalty", 0.0))
	var coins := int(result.get("coins", 0))
	var income := int(result.get("income", 0))
	var bonus := int(result.get("overAchievementCoins", 0))
	var next_stage := String(result.get("nextStage", RunManager.STAGE_SHOP))
	var earned_money := coins + income + bonus

	title_label.text = "第 %d 回合%s" % [round_id, "通过！" if win else "未通过"]

	var lines := PackedStringArray()
	lines.append("棋盘得分：%d" % points)
	lines.append("过关分数：%d" % objective)
	lines.append("时间：%.1f 秒，时间扣分：%.1f" % [time, penalty])
	lines.append("结算分：%d / %d" % [total_points, objective])

	if win:
		lines.append("本局金币：+%d，通关收入：+%d，超额奖励：+%d" % [coins, income, bonus])
		lines.append("本次可获得金币：+%d" % earned_money)
		lines.append("下一步：%s" % _next_stage_label(next_stage))
		action_button.text = _next_stage_button_text(next_stage)
		# 胜利：逐行显示文字 + 撒金币
		_reveal_text_with_animation(lines, true)
	else:
		lines.append("未通过原因：%s" % _failure_reason(result))
		lines.append("当前重试次数：%d" % int(RunManager.run.get("retries", 0)))
		action_button.text = "重试本回合"
		_reveal_text_with_animation(lines, false)


func _update_final_summary() -> void:
	if not RunManager.has_active_run():
		title_label.text = "结算"
		summary_label.text = "没有正在进行的冒险。"
		summary_label.modulate.a = 1.0
		action_button.text = "新的冒险"
		return

	var total_points := int(RunManager.run.get("totalPoints", 0))
	var retries := int(RunManager.run.get("retries", 0))
	var difficulty := String(RunManager.run.get("difficulty", "easy"))
	title_label.text = "冒险结算"
	action_button.text = "新的冒险"
	var lines := PackedStringArray()
	lines.append("总分：%d" % total_points)
	lines.append("重试次数：%d" % retries)
	lines.append("难度：%s" % difficulty)
	_reveal_text_with_animation(lines, true)


## -------------------------------------------------------------------------
## 逐行文字动画
## -------------------------------------------------------------------------

func _reveal_text_with_animation(lines: PackedStringArray, is_win: bool) -> void:
	summary_label.text = ""
	summary_label.modulate.a = 1.0
	for child in _lines_box.get_children():
		child.queue_free()

	# 逐行弹入：每行淡入 + 回弹放大
	for i in range(lines.size()):
		var line_label := _make_summary_line(lines[i], is_win)
		_lines_box.add_child(line_label)
		await get_tree().process_frame
		line_label.pivot_offset = line_label.size * 0.5
		var tween := create_tween().set_parallel(true)
		tween.tween_property(line_label, "modulate:a", 1.0, 0.22)
		tween.tween_property(line_label, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.13).timeout

	# 全部显示完毕后：胜利庆祝 / 失败盖章+抖动
	if is_win:
		_play_win_flourish()
	else:
		_play_lose_flourish()


func _make_summary_line(text: String, is_win: bool) -> Label:
	var line_label := Label.new()
	line_label.text = text
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_label.modulate.a = 0.0
	line_label.scale = Vector2(0.6, 0.6)
	if is_win and text.begins_with("本次可获得金币"):
		# 金币总收益行：金色高亮 + 更大字号
		WhatajongUI.tint_body_text(line_label, Color(0.78, 0.50, 0.04, 1.0), WhatajongUI.FONT_SIZE_SUBTITLE)
	else:
		WhatajongUI.tint_body_text(line_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	return line_label


## -------------------------------------------------------------------------
## 胜利 / 失败收尾动画
## -------------------------------------------------------------------------

func _play_win_flourish() -> void:
	# 标题冲击式放大回落
	title_label.pivot_offset = title_label.size * 0.5
	var title_tween := create_tween()
	title_tween.tween_property(title_label, "scale", Vector2(1.22, 1.22), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(title_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 面板轻微脉冲呼应
	var panel_tween := create_tween()
	panel_tween.tween_property(end_panel, "scale", Vector2(1.025, 1.025), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(end_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 两波金币迸发 + 彩纸飘落
	_play_celebration_burst(true)
	_rain_confetti()
	await get_tree().create_timer(0.24).timeout
	_play_celebration_burst(false)


func _play_lose_flourish() -> void:
	# 红色 LOSE 印章砸下，落地瞬间触发面板抖动，模拟盖章冲击
	_show_lose_stamp()
	await get_tree().create_timer(0.26).timeout
	_play_failure_shake()


func _show_lose_stamp() -> void:
	if not is_instance_valid(_celebration_layer):
		return
	var red := Color(0.76, 0.16, 0.12, 1.0)
	var stamp := Label.new()
	stamp.text = "LOSE"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.modulate.a = 0.0
	WhatajongUI.apply_display_font(stamp, 72)
	stamp.add_theme_color_override("font_color", red)

	# 橡皮印章样式：粗红边框 + 微红底
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.32, 0.26, 0.07)
	style.border_color = red
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.border_width_left = 5
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	stamp.add_theme_stylebox_override("normal", style)
	_celebration_layer.add_child(stamp)

	# 等一帧拿到尺寸后再定位与播放"砸章"动画
	await get_tree().process_frame
	stamp.pivot_offset = stamp.size * 0.5
	stamp.position = Vector2((end_panel.size.x - stamp.size.x) * 0.5, 46.0)
	stamp.rotation_degrees = -14.0
	stamp.scale = Vector2(2.6, 2.6)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(stamp, "modulate:a", 0.92, 0.16)
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stamp, "rotation_degrees", -9.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 落地后轻微回弹一下，更像盖章
	tween.chain().tween_property(stamp, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


func _play_failure_shake() -> void:
	# 失败：面板水平抖动，幅度逐渐衰减
	var origin_x := end_panel.position.x
	var tween := create_tween()
	for offset in [16.0, -13.0, 10.0, -7.0, 4.0, -2.0, 0.0]:
		tween.tween_property(end_panel, "position:x", origin_x + offset, 0.05).set_trans(Tween.TRANS_SINE)


func _play_celebration_burst(clear_previous: bool = true) -> void:
	if not is_instance_valid(_celebration_layer):
		return
	if clear_previous:
		for child in _celebration_layer.get_children():
			child.queue_free()

	var center := Vector2(end_panel.size.x * 0.5, 116.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(26):
		var coin := _make_burst_disc(rng.randf_range(10.0, 17.0), _coin_style)
		var angle := lerpf(-PI * 0.95, -PI * 0.05, float(i) / 25.0)
		var distance := rng.randf_range(120.0, 300.0)
		var target := center + Vector2(cos(angle), sin(angle)) * distance + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-12.0, 28.0))
		_animate_burst_disc(coin, center, target, rng.randf_range(-60.0, 60.0), 0.72 + i * 0.015)

	for i in range(16):
		var spark := _make_burst_disc(rng.randf_range(5.0, 9.0), _spark_style)
		var angle := rng.randf_range(-PI * 0.98, -PI * 0.02)
		var target := center + Vector2(cos(angle), sin(angle)) * rng.randf_range(90.0, 220.0)
		_animate_burst_disc(spark, center, target, rng.randf_range(-40.0, 40.0), 0.5 + i * 0.018)


func _rain_confetti() -> void:
	if not is_instance_valid(_celebration_layer):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var panel_width := end_panel.size.x
	var panel_height := end_panel.size.y

	for i in range(28):
		var piece := Panel.new()
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.size = Vector2(rng.randf_range(8.0, 14.0), rng.randf_range(5.0, 8.0))
		piece.pivot_offset = piece.size * 0.5
		piece.add_theme_stylebox_override("panel", _confetti_style)
		var tint := CONFETTI_PALETTE[rng.randi() % CONFETTI_PALETTE.size()]
		piece.modulate = Color(tint.r, tint.g, tint.b, 0.0)
		piece.position = Vector2(rng.randf_range(12.0, panel_width - 12.0), -12.0)
		piece.rotation_degrees = rng.randf_range(-30.0, 30.0)
		_celebration_layer.add_child(piece)

		var fall_time := rng.randf_range(0.9, 1.5)
		var delay := rng.randf_range(0.0, 0.35)
		var target_y := panel_height * rng.randf_range(0.55, 0.95)
		var drift := rng.randf_range(-46.0, 46.0)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(piece, "modulate:a", 0.95, 0.12).set_delay(delay)
		tween.tween_property(piece, "position:y", target_y, fall_time).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(piece, "position:x", piece.position.x + drift, fall_time).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(piece, "rotation_degrees", piece.rotation_degrees + rng.randf_range(-260.0, 260.0), fall_time).set_delay(delay)
		tween.tween_property(piece, "modulate:a", 0.0, 0.3).set_delay(delay + fall_time - 0.3)
		tween.finished.connect(piece.queue_free)


func _make_burst_disc(diameter: float, style: StyleBoxFlat) -> Panel:
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size = Vector2(diameter, diameter)
	disc.pivot_offset = disc.size * 0.5
	disc.modulate.a = 0.0
	disc.add_theme_stylebox_override("panel", style)
	_celebration_layer.add_child(disc)
	return disc


func _animate_burst_disc(disc: Control, center: Vector2, target: Vector2, spin_degrees: float, duration: float) -> void:
	disc.position = center - disc.size * 0.5
	disc.scale = Vector2(0.35, 0.35)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(disc, "position", target - disc.size * 0.5, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(disc, "scale", Vector2.ONE, minf(duration * 0.45, 0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(disc, "rotation_degrees", spin_degrees, duration).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(disc, "modulate:a", 1.0, 0.08)
	tween.chain().tween_property(disc, "modulate:a", 0.0, 0.22).set_delay(maxf(duration - 0.22, 0.0))
	tween.finished.connect(disc.queue_free)


func _make_disc_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.corner_radius_top_left = 99
	style.corner_radius_top_right = 99
	style.corner_radius_bottom_right = 99
	style.corner_radius_bottom_left = 99
	style.shadow_color = Color(0.24, 0.13, 0.02, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	return style


func _make_confetti_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	return style


## -------------------------------------------------------------------------
## 辅助
## -------------------------------------------------------------------------

func _next_stage_label(stage: String) -> String:
	match stage:
		RunManager.STAGE_REWARD:
			return "领取奖励"
		RunManager.STAGE_SHOP:
			return "进入商店"
		RunManager.STAGE_END:
			return "查看冒险总结"
		_:
			return "继续"


func _next_stage_button_text(stage: String) -> String:
	match stage:
		RunManager.STAGE_REWARD:
			return "领取奖励"
		RunManager.STAGE_SHOP:
			return "进入商店"
		RunManager.STAGE_END:
			return "查看总结"
		_:
			return "继续"


func _failure_reason(result: Dictionary) -> String:
	var end_condition := String(result.get("endCondition", ""))
	var total_points := int(result.get("totalPoints", 0))
	var objective := int(result.get("objective", 0))
	if end_condition == "no-pairs":
		return "没有可消对，棋盘未清空"
	if total_points < objective:
		return "结算分不足"
	return "棋盘未清空"


func _on_new_run_button_pressed() -> void:
	if _is_round_settlement():
		_continue_from_round_summary()
		return

	RunManager.start_new_run()
	RunManager.enter_stage(RunManager.STAGE_INTRO)


func _continue_from_round_summary() -> void:
	var result := RunManager.last_round_result
	if not bool(result.get("win", false)):
		RunManager.retry_round()
		RunManager.enter_stage(RunManager.STAGE_GAME)
		return

	var next_stage := String(result.get("nextStage", RunManager.STAGE_SHOP))
	RunManager.advance_after_win()
	RunManager.enter_stage(next_stage)
