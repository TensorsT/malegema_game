extends Control

## PvPResult — 联机对战结算画面

@onready var main_panel: Panel = $MainPanel
@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var result_label: Label = $MainPanel/VBoxContainer/ResultLabel
@onready var score_container: VBoxContainer = $MainPanel/VBoxContainer/ScoreContainer
@onready var rematch_button: Button = $MainPanel/VBoxContainer/RematchButton
@onready var lobby_button: Button = $MainPanel/VBoxContainer/LobbyButton
@onready var quit_button: Button = $MainPanel/VBoxContainer/QuitButton


func _ready() -> void:
	_apply_whatajong_ui()
	_show_result()


func _show_result() -> void:
	var my_id := PvPNetwork.get_local_peer_id()
	var i_won: bool = PvPState.match_wins.get(my_id, 0) >= PvPState.WIN_NEED

	if i_won:
		title_label.text = "🎉 你赢了！"
		result_label.text = "恭喜你赢得了本场对战！"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	else:
		title_label.text = "😔 你输了"
		result_label.text = "对手获得了最终胜利。"
		title_label.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))

	# 显示比分
	_add_score_row("你（本局）", PvPState.get_score(my_id))
	var opponent_id := 2 if my_id == 1 else 1
	_add_score_row("对手（本局）", PvPState.get_score(opponent_id))
	_add_score_row("总战绩", int(PvPState.match_wins.get(my_id, 0)))
	_add_score_row("对手战绩", int(PvPState.match_wins.get(opponent_id, 0)))


func _add_score_row(name: String, score: int) -> void:
	var label := Label.new()
	label.text = "%s：%d 分" % [name, score]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WhatajongUI.apply_display_font(label, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(label, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_BODY)
	score_container.add_child(label)


func _on_rematch_button_pressed() -> void:
	PvPState.reset_for_new_match()
	get_tree().change_scene_to_file("res://scene/pvp_board.tscn")


func _on_lobby_button_pressed() -> void:
	PvPNetwork.disconnect_from_network()
	get_tree().change_scene_to_file("res://scene/pvp_lobby.tscn")


func _on_quit_button_pressed() -> void:
	PvPNetwork.disconnect_from_network()
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")


func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(main_panel, WhatajongUI.COLOR_DOT, Color(0.97, 0.94, 0.86, 0.88), 30, 24)
	WhatajongUI.apply_display_font(title_label, WhatajongUI.FONT_SIZE_TITLE)
	WhatajongUI.apply_display_font(result_label, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.apply_display_font(rematch_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(lobby_button, WhatajongUI.FONT_SIZE_BUTTON)
	WhatajongUI.apply_display_font(quit_button, WhatajongUI.FONT_SIZE_BUTTON)

	WhatajongUI.apply_button(rematch_button, WhatajongUI.COLOR_BAM, 0.92)
	WhatajongUI.apply_button(lobby_button, WhatajongUI.COLOR_CRACK, 0.92)
	WhatajongUI.apply_button(quit_button, Color(0.85, 0.25, 0.25), 0.90)

	WhatajongUI.tint_body_text(result_label, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_BODY)
