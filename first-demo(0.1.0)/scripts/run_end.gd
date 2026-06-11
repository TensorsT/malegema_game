extends Control

@onready var end_panel: Panel = $EndPanel
@onready var title_label: Label = $EndPanel/VBoxContainer/TitleLabel
@onready var summary_label: Label = $EndPanel/VBoxContainer/SummaryLabel
@onready var action_button: Button = $EndPanel/VBoxContainer/NewRunButton

var _celebration_layer: Control
var _coin_style: StyleBoxFlat
var _spark_style: StyleBoxFlat


func _ready() -> void:
	_apply_ui()
	_setup_celebration_layer()
	# 初始状态：面板完全透明，由入场动画逐步显示
	end_panel.modulate.a = 0.0
	end_panel.position.y += 22.0
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


## -------------------------------------------------------------------------
## 入场动画
## -------------------------------------------------------------------------

func _play_entrance_animation() -> void:
	# 面板淡入 + 轻微缩放（从 0.96 放大到 1.0）并上浮归位。
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale = Vector2(0.96, 0.96)
	var panel_target_y := end_panel.position.y - 22.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(end_panel, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(end_panel, "scale", Vector2(1.0, 1.0), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(end_panel, "position:y", panel_target_y, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 标题延迟淡入
	await get_tree().create_timer(0.2).timeout
	var tween2 := create_tween()
	tween2.tween_property(title_label, "modulate:a", 1.0, 0.3)

	# 延迟后填充结算文字（逐行显示）
	await get_tree().create_timer(0.45).timeout
	_update_summary()

	# 按钮最后淡入
	await get_tree().create_timer(0.6).timeout
	var tween3 := create_tween()
	tween3.tween_property(action_button, "modulate:a", 1.0, 0.25)


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

	# 逐行显示，每行间隔 0.18 秒
	for i in range(lines.size()):
		await get_tree().create_timer(0.18).timeout
		summary_label.text += lines[i] + "\n"

	# 全部显示完毕后，如果是胜利则撒金币
	if is_win:
		_play_celebration_burst()


func _play_celebration_burst() -> void:
	if not is_instance_valid(_celebration_layer):
		return
	for child in _celebration_layer.get_children():
		child.queue_free()

	var center := Vector2(end_panel.size.x * 0.5, 116.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(16):
		var coin := _make_burst_disc(rng.randf_range(8.0, 13.0), _coin_style)
		var angle := lerpf(-PI * 0.92, -PI * 0.08, float(i) / 15.0)
		var distance := rng.randf_range(88.0, 190.0)
		var target := center + Vector2(cos(angle), sin(angle)) * distance + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-8.0, 22.0))
		_animate_burst_disc(coin, center, target, rng.randf_range(-35.0, 35.0), 0.58 + i * 0.015)

	for i in range(10):
		var spark := _make_burst_disc(rng.randf_range(4.0, 7.0), _spark_style)
		var angle := rng.randf_range(-PI * 0.95, -PI * 0.05)
		var target := center + Vector2(cos(angle), sin(angle)) * rng.randf_range(70.0, 150.0)
		_animate_burst_disc(spark, center, target, rng.randf_range(-20.0, 20.0), 0.42 + i * 0.018)


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
