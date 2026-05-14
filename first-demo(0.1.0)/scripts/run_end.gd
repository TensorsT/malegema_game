extends Control

@onready var end_panel: Panel = $EndPanel
@onready var title_label: Label = $EndPanel/VBoxContainer/TitleLabel
@onready var summary_label: Label = $EndPanel/VBoxContainer/SummaryLabel
@onready var action_button: Button = $EndPanel/VBoxContainer/NewRunButton


func _ready() -> void:
	_apply_ui()
	_update_summary()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(end_panel, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(action_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_button(action_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_BAM.darkened(0.35))
	WhatajongUI.tint_body_text(summary_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)


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

	title_label.text = "第 %d 回合%s" % [round_id, "通过" if win else "未通过"]

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
	else:
		lines.append("未通过原因：%s" % _failure_reason(result))
		lines.append("当前重试次数：%d" % int(RunManager.run.get("retries", 0)))
		action_button.text = "重试本回合"

	summary_label.text = "\n".join(lines)


func _update_final_summary() -> void:
	if not RunManager.has_active_run():
		title_label.text = "结算"
		summary_label.text = "没有正在进行的冒险。"
		action_button.text = "新的冒险"
		return

	var total_points := int(RunManager.run.get("totalPoints", 0))
	var retries := int(RunManager.run.get("retries", 0))
	var difficulty := String(RunManager.run.get("difficulty", "easy"))
	title_label.text = "冒险结算"
	action_button.text = "新的冒险"
	summary_label.text = "总分：%d\n重试次数：%d\n难度：%s" % [total_points, retries, difficulty]


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
