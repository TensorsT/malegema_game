extends Control

@onready var end_panel: Panel = $EndPanel
@onready var title_label: Label = $EndPanel/VBoxContainer/TitleLabel
@onready var summary_label: Label = $EndPanel/VBoxContainer/SummaryLabel
@onready var new_run_button: Button = $EndPanel/VBoxContainer/NewRunButton


func _ready() -> void:
	_apply_ui()
	_update_summary()


func _apply_ui() -> void:
	WhatajongUI.apply_panel(end_panel, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.9), 28, 26)
	WhatajongUI.apply_display_font(title_label)
	WhatajongUI.apply_display_font(new_run_button)
	WhatajongUI.apply_button(new_run_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_BAM.darkened(0.35))
	WhatajongUI.tint_body_text(summary_label)


func _update_summary() -> void:
	var total_points := int(RunManager.run.get("totalPoints", 0))
	var attempts := int(RunManager.run.get("attempts", 0)) + 1
	var difficulty := String(RunManager.run.get("difficulty", "easy"))
	summary_label.text = "总分：%d\n尝试次数：%d\n难度：%s" % [total_points, attempts, difficulty]


func _on_new_run_button_pressed() -> void:
	RunManager.start_new_run()
	RunManager.enter_stage(RunManager.STAGE_INTRO)
