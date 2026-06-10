extends Control

@onready var end_panel: Panel = $EndPanel
@onready var title_label: Label = $EndPanel/VBoxContainer/TitleLabel
@onready var summary_label: Label = $EndPanel/VBoxContainer/SummaryLabel
@onready var action_button: Button = $EndPanel/VBoxContainer/NewRunButton

var _coin_particles: CPUParticles2D


func _ready() -> void:
	_apply_ui()
	_setup_coin_particles()
	# 初始状态：面板完全透明，由入场动画逐步显示
	end_panel.modulate.a = 0.0
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


func _setup_coin_particles() -> void:
	_coin_particles = CPUParticles2D.new()
	_coin_particles.position = Vector2(300, 120)
	_coin_particles.emitting = false
	_coin_particles.amount = 40
	_coin_particles.lifetime = 2.0
	_coin_particles.one_shot = true
	_coin_particles.explosiveness = 0.3
	_coin_particles.randomness = 0.4
	_coin_particles.direction = Vector2(0, -1)
	_coin_particles.spread = 160.0
	_coin_particles.initial_velocity_min = 60.0
	_coin_particles.initial_velocity_max = 200.0
	_coin_particles.angular_velocity_min = -280.0
	_coin_particles.angular_velocity_max = 280.0
	_coin_particles.scale_amount_min = 0.4
	_coin_particles.scale_amount_max = 1.0
	_coin_particles.color = Color(1, 0.85, 0.15, 1)

	# 金色渐变
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 0.95, 0.6, 1),
		Color(1, 0.85, 0.15, 1),
		Color(0.8, 0.55, 0.1, 1),
	])
	_coin_particles.color_ramp = ramp

	# 尝试加载金币纹理（静默降级）
	var tex_path := "res://textures/1.webp"
	if ResourceLoader.exists(tex_path):
		_coin_particles.texture = load(tex_path) as Texture2D

	end_panel.add_child(_coin_particles)


## -------------------------------------------------------------------------
## 入场动画
## -------------------------------------------------------------------------

func _play_entrance_animation() -> void:
	# 面板淡入 + 轻微缩放（从 0.92 放大到 1.0）
	end_panel.pivot_offset = Vector2(300, 250)
	end_panel.scale = Vector2(0.92, 0.92)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(end_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(end_panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	tween3.tween_property(action_button, "modulate:a", 1.0, 0.3)


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
		_emit_coin_particles()


func _emit_coin_particles() -> void:
	if is_instance_valid(_coin_particles):
		_coin_particles.restart()
		_coin_particles.emitting = true


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
